import Foundation

struct RunwayResult {
    var salMonthsTotal: Int
    var dynamicRuhens: Int
    var algMonths: Int
    var postPhaseMonths: Int
    var exhaustedMonth: Int
    var faRefundOct2028: Double
    var bridgeDeficitMax: Double
    var firstDeficitM: Int?
    var curve: [Double]
}

private var monthNames: [String] {
    Lang.shared.isEnglish
        ? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        : ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
}

func monthLabel(_ offsetFromJan27: Int) -> String {
    let names = monthNames
    let total = max(0, offsetFromJan27)
    return "\(names[total % 12]) \(2027 + total / 12)"
}

/// Compact label for crowded axes, e.g. "Feb 27".
func monthLabelShort(_ offsetFromJan27: Int) -> String {
    let names = monthNames
    let total = max(0, offsetFromJan27)
    let yy = (2027 + total / 12) % 100
    return "\(names[total % 12]) \(String(format: "%02d", yy))"
}

enum Runway {
    /// Port of `simulateRunwayScenario` (Section C: Cash-Burn & Reichweite).
    static func simulate(_ ctx: SimCtx, _ i: Inputs, sprinter: Bool) -> RunwayResult {
        let monthlyLiving = max(0, i.runwayExpenses)
        let alg1TotalEligible = max(0, i.runwayAlg1Months)
        let upfrontSpend = max(0, i.runwayUpfrontSpend)
        let customGkv = max(0, i.runwayCustomGkv)
        let monthlyRealRate = (i.runwayRealReturn / 100) / 12
        let minijobMonthly = max(0, i.runwayMinijob)
        let minijobDuringAlg1 = min(165, minijobMonthly)

        let postAlg1Gkv: Double
        switch i.runwayGkvMode {
        case .min: postAlg1Gkv = ctx.gkvMinMonat
        case .fam: postAlg1Gkv = 0
        case .custom: postAlg1Gkv = customGkv
        }

        let salMonthsTotal = sprinter ? ctx.preMonths : ctx.preMonths + ctx.fristMonate
        let salMonthsIn2027 = min(12, salMonthsTotal)
        let salMonthsIn2028 = max(0, salMonthsTotal - 12)

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

        let rem2027 = max(0, 12 - salMonthsIn2027)
        let ruhens2027 = min(dynamicRuhens, rem2027)
        let grace2027 = (sprinter && ctx.preExitGkvPflicht && ruhens2027 > 0) ? 1 : 0
        let payableRuhens2027 = max(0, ruhens2027 - grace2027)
        let alg2027 = max(0, min(algMonths, rem2027 - ruhens2027))

        let grossSal2027 = Double(salMonthsIn2027) * ctx.altesMonatsgehalt
        let taxPaidSal2027 = tc.withholding(
            TaxMath.employmentZve(grossSal2027, zb: ctx.zb, kinder: ctx.kinder) + ctx.partnerZveBasis).total

        let maxRuerupScen = max(0, Const.maxAltersvorsorge * ctx.spl
                                - min(grossSal2027, Const.bbgRV) * 0.186
                                - (ctx.spl == 2 ? min(ctx.pGehalt, Const.bbgRV) * 0.186 : 0))
        var effRuerup = min(ctx.ruerup, maxRuerupScen)
        let baseZveBeforeRuerup = TaxMath.employmentZve(grossSal2027, zb: ctx.zb, kinder: ctx.kinder)
            - Double(payableRuhens2027) * ctx.gkvHoechstsatzMonat - ctx.iab + ctx.partnerZveBasis
        if i.runwayCapRuerupSweetSpot {
            effRuerup = min(effRuerup, max(0, baseZveBeforeRuerup))
        }

        let zve2027 = baseZveBeforeRuerup - effRuerup
        let prog2027 = Double(alg2027) * ctx.alg1Monat
        let finalTax2027 = tc.annual(zve2027, fuenftel: true, abf: taxableAbf, prog: prog2027).total
        // Signed: negative = Nachzahlung
        let faRefundOct2028 = (taxPaidSal2027 + upfrontTaxAbf) - finalTax2027

        let rem2028AfterSal = max(0, 12 - salMonthsIn2028)
        let ruhens2028 = max(0, dynamicRuhens - ruhens2027)
        let alg2028 = max(0, min(algMonths - alg2027, rem2028AfterSal - ruhens2028))
        let grossSal2028 = Double(salMonthsIn2028) * ctx.altesMonatsgehalt
        var faSettlementOct2029 = 0.0
        if ctx.spl == 2 || salMonthsIn2028 > 0 {
            let empZve2028 = TaxMath.employmentZve(grossSal2028, zb: ctx.zb, kinder: ctx.kinder)
            let withheld2028 = tc.withholding(empZve2028 + ctx.partnerZveBasis).total
            let zve2028 = empZve2028 - Double(ruhens2028) * ctx.gkvHoechstsatzMonat + ctx.partnerZveBasis
            let finalTax2028 = tc.annual(zve2028, fuenftel: false, abf: 0, prog: Double(alg2028) * ctx.alg1Monat).total
            faSettlementOct2029 = withheld2028 - finalTax2028
        }

        let oct2028Idx = 21
        let oct2029Idx = 33
        let maxM = 240
        var cash = 0.0
        var payoutDone = false, ref28Done = false, ref29Done = false
        var bridgeDeficitMax = 0.0
        var firstDeficitM: Int? = nil
        var curve: [Double] = []

        let monthlyNetSal: Double = (grossSal2027 > 0 && salMonthsIn2027 > 0)
            ? (grossSal2027 - TaxMath.sozAbzug(grossSal2027, zb: ctx.zb, kinder: ctx.kinder) - taxPaidSal2027) / Double(salMonthsIn2027)
            : (ctx.altesMonatsgehalt - TaxMath.sozAbzug(ctx.altesMonatsgehalt, zb: ctx.zb, kinder: ctx.kinder)) * 0.65

        var exhaustedMonth = maxM
        // The Abfindung is always assumed to be paid in 2027 (December at the latest).
        let payoutM = min(salMonthsTotal, 11)

        for m in 0..<maxM {
            if !payoutDone && m == payoutM {
                cash += sofortNettoAbf - effRuerup - upfrontSpend
                payoutDone = true
            }
            if !ref28Done && m == oct2028Idx {
                cash += faRefundOct2028
                ref28Done = true
            }
            if !ref29Done && m == oct2029Idx {
                cash += faSettlementOct2029
                ref29Done = true
            }

            if m < salMonthsTotal {
                if i.runwayIncludeSalarySavings { cash += max(0, monthlyNetSal - monthlyLiving) }
            } else if m < salMonthsTotal + dynamicRuhens {
                let ruhIdx = m - salMonthsTotal
                let gkvThisM = (sprinter && ctx.preExitGkvPflicht && ruhIdx == 0) ? 0 : ctx.gkvHoechstsatzMonat
                cash -= (monthlyLiving + gkvThisM - minijobMonthly)
            } else if m < salMonthsTotal + dynamicRuhens + algMonths {
                cash += ctx.alg1Monat + minijobDuringAlg1 - monthlyLiving
            } else {
                cash -= (monthlyLiving + postAlg1Gkv - minijobMonthly)
            }

            if cash > 0 && monthlyRealRate != 0 {
                cash *= (1 + monthlyRealRate)
            }

            if m < oct2028Idx && cash < 0 {
                if firstDeficitM == nil { firstDeficitM = m }
                bridgeDeficitMax = max(bridgeDeficitMax, abs(cash))
            }

            curve.append(jsRound(cash))

            let allInjected = payoutDone && ref28Done && (faSettlementOct2029 <= 0 || ref29Done)
            if allInjected && cash <= 0 {
                exhaustedMonth = m + 1
                break
            }
        }

        let postPhase = max(0, exhaustedMonth - (salMonthsTotal + dynamicRuhens + algMonths))
        return RunwayResult(salMonthsTotal: salMonthsTotal, dynamicRuhens: dynamicRuhens, algMonths: algMonths,
                            postPhaseMonths: postPhase, exhaustedMonth: exhaustedMonth,
                            faRefundOct2028: faRefundOct2028, bridgeDeficitMax: bridgeDeficitMax,
                            firstDeficitM: firstDeficitM, curve: curve)
    }
}
