import Foundation

struct CrossoverResult {
    var exitM: Int
    var jobStartM: Int
    var baseOldNet: Double
    var baseNewNet: Double
    var cushionAtJobStart: Double
    var breakevenMonthFromJan27: Int?
    var breakevenMonthsInNewJob: Int?
    var advSeries: [Double]
}

enum Crossover {
    /// Port of `simulateCrossoverScenario` (Section D: Gehalts-Switch / Break-Even).
    static func simulate(_ ctx: SimCtx, _ i: Inputs, sprinter: Bool,
                         newMonthlyGross: Double, delay: Int, growth: Double) -> CrossoverResult {
        let alg1TotalEligible = max(0, i.runwayAlg1Months)
        let upfrontSpend = max(0, i.runwayUpfrontSpend)
        let monthlyRealRate = (i.runwayRealReturn / 100) / 12
        let postAlg1Gkv: Double
        switch i.runwayGkvMode {
        case .min: postAlg1Gkv = ctx.gkvMinMonat
        case .fam: postAlg1Gkv = 0
        case .custom: postAlg1Gkv = max(0, i.runwayCustomGkv)
        }

        let exitM = sprinter ? ctx.preMonths : ctx.preMonths + ctx.fristMonate
        let jobStartM = exitM + delay

        let fristD = Double(ctx.fristMonate)
        let grossAbf = sprinter ? ctx.abfNoTurbo + fristD * ctx.altesMonatsgehalt * ctx.turboFaktor : ctx.abfNoTurbo
        let effBav = min(ctx.bav, grossAbf)
        let effDrv = min(max(0, grossAbf - effBav), ctx.drvRaw)
        let taxableAbf = max(0, grossAbf - effBav - effDrv * 0.5)
        let cashAbfBeforeTax = max(0, grossAbf - effBav - effDrv)

        let dynamicRuhens = sprinter
            ? Calculator.ruhensMonths(abfindung: grossAbf, monthly: ctx.altesMonatsgehalt,
                                      frist: ctx.fristMonate, anteil: ctx.ruhensAnteil)
            : 0
        let sperrzeitTrim = sprinter ? Calculator.sperrzeitMonths(alg1Months: alg1TotalEligible) : 0
        let tc = ctx.tax
        let algMonths = max(0, alg1TotalEligible - sperrzeitTrim)

        let agTaxBase = tc.withholding(ctx.agZveBasis).total
        let agTaxFull = tc.withholding(ctx.agZveBasis + taxableAbf).total
        let upfrontTaxAbf = max(0, agTaxFull - agTaxBase)
        let sofortNettoAbf = max(0, cashAbfBeforeTax - upfrontTaxAbf)

        let oldSalMonths2027 = min(12, exitM)
        let newSalMonths2027 = max(0, 12 - min(12, jobStartM))
        let gapMonths2027 = max(0, min(12, jobStartM) - oldSalMonths2027)
        let ruhens2027 = min(dynamicRuhens, gapMonths2027)
        let grace2027 = (sprinter && ctx.preExitGkvPflicht && ruhens2027 > 0) ? 1 : 0
        let payableRuhens2027 = max(0, ruhens2027 - grace2027)
        let alg2027 = max(0, min(algMonths, gapMonths2027 - ruhens2027))

        let gross2027 = Double(oldSalMonths2027) * ctx.altesMonatsgehalt + Double(newSalMonths2027) * newMonthlyGross
        let taxPaid2027 = tc.withholding(
            TaxMath.employmentZve(gross2027, zb: ctx.zb, kinder: ctx.kinder) + ctx.partnerZveBasis).total

        let maxRuerupScen = max(0, Const.maxAltersvorsorge * ctx.spl
                                - min(gross2027, Const.bbgRV) * 0.186
                                - (ctx.spl == 2 ? min(ctx.pGehalt, Const.bbgRV) * 0.186 : 0))
        var effRuerup = min(ctx.ruerup, maxRuerupScen)
        let baseZveBeforeRuerup = TaxMath.employmentZve(gross2027, zb: ctx.zb, kinder: ctx.kinder)
            - Double(payableRuhens2027) * ctx.gkvHoechstsatzMonat - ctx.iab + ctx.partnerZveBasis
        if i.runwayCapRuerupSweetSpot { effRuerup = min(effRuerup, max(0, baseZveBeforeRuerup)) }

        let zve2027 = baseZveBeforeRuerup - effRuerup
        let finalTax2027 = tc.annual(zve2027, fuenftel: true, abf: taxableAbf, prog: Double(alg2027) * ctx.alg1Monat).total
        // Signed: negative = Nachzahlung
        let faRefundOct2028 = (taxPaid2027 + upfrontTaxAbf) - finalTax2027

        func monthlyNet(_ monthlyBrutto: Double) -> Double {
            if monthlyBrutto <= 0 { return 0 }
            let ann = monthlyBrutto * 12
            let soz = TaxMath.sozAbzug(ann, zb: ctx.zb, kinder: ctx.kinder)
            let tax = TaxCtx(spl: 1, kinder: ctx.kinder, kist: ctx.kist)
                .withholding(TaxMath.employmentZve(ann, zb: ctx.zb, kinder: ctx.kinder)).total
            return (ann - soz - tax) / 12
        }
        let baseOldNet = monthlyNet(ctx.altesMonatsgehalt)
        let baseNewNet = monthlyNet(newMonthlyGross)

        let oct2028Idx = 21
        let maxM = 360
        // The Abfindung is always assumed to be paid in 2027 (December at the latest).
        let payoutM = min(exitM, 11)
        var advantage = 0.0
        var payoutDone = false, ref28Done = false
        var cushionAtJobStart = 0.0
        var breakeven: Int? = nil
        var series: [Double] = []

        for m in 0..<maxM {
            if !payoutDone && m == payoutM {
                advantage += sofortNettoAbf - effRuerup - upfrontSpend
                payoutDone = true
            }
            if !ref28Done && m == oct2028Idx {
                advantage += faRefundOct2028
                ref28Done = true
            }

            let yearIdx = m / 12
            let growthFactor = pow(1 + growth, Double(yearIdx))
            let oldNet = baseOldNet * growthFactor
            let newNet = baseNewNet * growthFactor

            if m < exitM {
                // no difference to staying
            } else if m < jobStartM {
                let gapIdx = m - exitM
                if gapIdx < dynamicRuhens {
                    let gkvThisM = (sprinter && ctx.preExitGkvPflicht && gapIdx == 0) ? 0 : ctx.gkvHoechstsatzMonat
                    advantage -= (oldNet + gkvThisM)
                } else if gapIdx < dynamicRuhens + algMonths {
                    advantage += ctx.alg1Monat - oldNet
                } else {
                    advantage -= (oldNet + postAlg1Gkv)
                }
            } else {
                if m == jobStartM {
                    cushionAtJobStart = advantage + (ref28Done ? 0 : faRefundOct2028)
                }
                advantage -= max(0, oldNet - newNet)
            }

            if advantage > 0 && monthlyRealRate != 0 {
                advantage *= (1 + monthlyRealRate)
            }

            series.append(jsRound(advantage))

            if payoutDone && ref28Done && breakeven == nil && advantage <= 0 {
                breakeven = m + 1
            }
            if let be = breakeven, m >= max(120, be + 12) { break }
        }

        if jobStartM <= exitM {
            cushionAtJobStart = (sofortNettoAbf - effRuerup - upfrontSpend) + faRefundOct2028
        }

        let beInJob = breakeven.map { max(0, $0 - jobStartM) }
        return CrossoverResult(exitM: exitM, jobStartM: jobStartM, baseOldNet: baseOldNet, baseNewNet: baseNewNet,
                               cushionAtJobStart: cushionAtJobStart, breakevenMonthFromJan27: breakeven,
                               breakevenMonthsInNewJob: beInJob, advSeries: series)
    }
}
