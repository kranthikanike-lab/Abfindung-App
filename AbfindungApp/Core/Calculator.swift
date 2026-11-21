import Foundation

/// Simulation context shared by Section C (Runway) and D (Gehalts-Switch).
struct SimCtx {
    var altesMonatsgehalt: Double
    var preMonths: Int
    var fristMonate: Int
    var abfNoTurbo: Double
    var turboFaktor: Double
    var agZveBasis: Double
    var spl: Double
    var pGehalt: Double
    var partnerZveBasis: Double
    var zb: Double
    var kinder: Double
    var bav: Double
    var drvRaw: Double
    var drvTaxFree: Double
    var ruerup: Double
    var iab: Double
    var iabInvest: Double
    var gkvHoechstsatzMonat: Double
    var gkvMinMonat: Double
    var alg1Monat: Double
    var preExitGkvPflicht: Bool
}

struct OptSaving {
    var amount = 0.0
    var savings = 0.0
    var percent: Double { amount > 0 ? savings / amount * 100 : 0 }
}

struct SplittingInfo {
    var maxPartnerGross: Double
    var advantage: Double
}

struct Results {
    // Info lines
    var jahresBrutto = 0.0
    var gkvHoechst = 0.0
    var kfb = 0.0
    var kg = 0.0
    var alg1Monat = 0.0
    var salMonthsStd = 0
    var salMonthsSpr = 0
    var sprinterBruttoPraemie = 0.0

    // Optimierung
    var maxRuerup = 0.0
    var ruerupSweetSpot = 0.0
    var iabSweetInvest = 0.0
    var iabSweetAbzug = 0.0
    var bav = 0.0
    var drvRaw = 0.0
    var drvTaxFree = 0.0
    var ruerup = 0.0
    var iab = 0.0
    var iabInvest = 0.0
    var totalOptVolume = 0.0
    var bavSaving = OptSaving()
    var drvSaving = OptSaving()
    var ruerupSaving = OptSaving()
    var iabSaving = OptSaving()

    // Sprinter
    var isolatedNettoPraemie = 0.0
    var pureFuenftelAdvantage = 0.0
    var lostNetSalary = 0.0
    var gkvTurboSim = 0.0
    var rvSim = 0.0
    var alg1Sim = 0.0
    var sprinterGains = 0.0
    var sprinterLosses = 0.0
    var sprinterNetDiff = 0.0

    var splitting: SplittingInfo?

    // KPIs
    var netVoll = 0.0
    var erstattung = 0.0
    var netFf = 0.0
    var rateUpfront = 0.0
    var rateFinal = 0.0
    var liq27 = 0.0
    var liq28 = 0.0

    // Tables
    var abfNoTurbo = 0.0
    var praemieBrutto = 0.0
    var effectiveAbfindung = 0.0
    var barBruttoTaxable = 0.0
    var barBruttoCash = 0.0
    var einbehalten = 0.0
    var zveAfterAll = 0.0
    var finalAbfTax = 0.0
    var netGehaltBase = 0.0
    var gkvPenalty2027 = 0.0

    // Chart 3
    var drvFuenftelRefund2028 = 0.0
    var baseFuenftelRefund = 0.0

    var ctx: SimCtx? = nil
    var runwayStd: RunwayResult? = nil
    var runwaySpr: RunwayResult? = nil
    var crossStd: CrossoverResult? = nil
    var crossSpr: CrossoverResult? = nil
    var crossMonthlyLoss = 0.0
}

enum Calculator {
    /// Port of `berechneAlles()` from the HTML calculator.
    static func compute(_ i: Inputs) -> Results {
        var r = Results()

        let alt = max(0, i.altesMonatsgehalt)
        let preMonths = max(0, i.startMonth - 1)
        let frist = max(0, i.fristMonate)
        let abfNoTurbo = max(0, i.bruttoAbfindung)
        let neues = max(0, i.neuesGehalt)
        let agFiktiv = max(0, i.agFiktivGehalt)
        let zb = max(0, i.zusatzbeitrag)
        let kinder = i.kinder
        let spl = i.spl
        let pGehalt = i.splitting ? max(0, i.partnerGehalt) : 0
        let isTurbo = i.isTurbo
        let turboFaktor = max(0, i.turboFaktor)
        let fristD = Double(frist)

        let gkvHoechst = TaxMath.gkvHoechstsatzMonat(zb)
        let gkvMin = TaxMath.gkvMindestMonat(zb, kinder: kinder)
        let alg1Monat = TaxMath.autoAlg1(monthlyGross: alt, satz: i.alg1Satz)

        r.jahresBrutto = alt * 12
        r.gkvHoechst = gkvHoechst
        r.kfb = kinder * Const.kinderFreibetrag
        r.kg = kinder * Const.kindergeld
        r.alg1Monat = alg1Monat

        let salMonthsStd = min(12, preMonths + frist)
        let salMonthsSpr = preMonths
        r.salMonthsStd = salMonthsStd
        r.salMonthsSpr = salMonthsSpr

        let bgNoTurbo = Double(salMonthsStd) * alt + neues
        let bgTurbo = Double(salMonthsSpr) * alt + neues
        let bg = isTurbo ? bgTurbo : bgNoTurbo

        let praemieBrutto = isTurbo ? fristD * alt * turboFaktor : 0
        r.sprinterBruttoPraemie = fristD * alt * turboFaktor
        let effAbf = abfNoTurbo + praemieBrutto

        let maxRuerup = max(0, Const.maxAltersvorsorge * spl
                            - min(bg, Const.bbgRV) * 0.186
                            - (i.splitting ? min(pGehalt, Const.bbgRV) * 0.186 : 0))
        r.maxRuerup = maxRuerup

        let opt = i.optEnabled
        let bav = opt ? min(effAbf, i.bav) : 0
        let drvRaw = opt ? min(max(0, effAbf - bav), i.drv) : 0
        let ruerup = opt ? min(maxRuerup, i.ruerup) : 0
        let iabInvest = opt ? i.iabInvest : 0
        let iab = iabInvest * 0.5

        let drvTaxFree = drvRaw * 0.5
        let drvTaxable = drvRaw * 0.5
        let barCash = max(0, effAbf - bav - drvRaw)
        let barTaxable = max(0, effAbf - bav - drvTaxFree)

        r.bav = bav; r.drvRaw = drvRaw; r.drvTaxFree = drvTaxFree
        r.ruerup = ruerup; r.iab = iab; r.iabInvest = iabInvest
        r.totalOptVolume = bav + drvRaw + ruerup + iabInvest

        let dynRuhens = min(12, frist, Int((0.45 * effAbf / max(1, alt)).rounded(.up)))
        let ruhensIn2027 = isTurbo ? min(dynRuhens, max(0, 12 - salMonthsSpr)) : 0
        let freeGkvGrace = (isTurbo && i.preExitGkvPflicht && ruhensIn2027 > 0) ? 1 : 0
        let payableGkv2027 = max(0, ruhensIn2027 - freeGkvGrace)
        let gkvPenalty2027 = Double(payableGkv2027) * gkvHoechst
        r.gkvPenalty2027 = gkvPenalty2027

        // Standard scenario (Frist absitzen)
        let sozNoTurbo = TaxMath.sozAbzug(bgNoTurbo, zb: zb, kinder: kinder)
        let barNoTurbo = max(0, abfNoTurbo - bav - drvTaxFree)
        let partnerZve = i.splitting ? TaxMath.employmentZve(pGehalt, zb: zb, kinder: kinder) : 0
        let zveBasisNoTurbo = TaxMath.employmentZve(bgNoTurbo, zb: zb, kinder: kinder) + partnerZve
        let taxNoTurbo = TaxMath.totalTax(zve: zveBasisNoTurbo - iab - ruerup, spl: spl, fuenftel: true,
                                          abf: barNoTurbo, kinder: kinder).total
        let wealthNoTurbo = (bgNoTurbo - sozNoTurbo) + max(0, abfNoTurbo - bav - drvRaw) - taxNoTurbo

        // Active scenario
        let sozRegular = TaxMath.sozAbzug(bg, zb: zb, kinder: kinder)
        let zveBasisActive = TaxMath.employmentZve(bg, zb: zb, kinder: kinder) - gkvPenalty2027 + partnerZve
        let zveAfterAll = zveBasisActive - iab - ruerup
        let T3 = TaxMath.totalTax(zve: zveAfterAll, spl: spl, fuenftel: true, abf: barTaxable, kinder: kinder).total

        r.ruerupSweetSpot = jsRound(min(maxRuerup, max(0, zveBasisActive - iab)))
        let remBeforeIab = max(0, zveBasisActive - ruerup)
        r.iabSweetInvest = jsRound(remBeforeIab * 2)
        r.iabSweetAbzug = remBeforeIab

        // Sprinter simulation (independent of toggle)
        let ruhensSim = min(dynRuhens, max(0, 12 - salMonthsSpr))
        let graceSim = (i.preExitGkvPflicht && ruhensSim > 0) ? 1 : 0
        let gkvTurboSim = Double(max(0, ruhensSim - graceSim)) * gkvHoechst
        let zveBasisTurboSim = TaxMath.employmentZve(bgTurbo, zb: zb, kinder: kinder) - gkvTurboSim + partnerZve
        let zveAfterAllTurboSim = zveBasisTurboSim - iab - ruerup

        let taxSalNoTurbo = TaxMath.totalTax(zve: TaxMath.employmentZve(bgNoTurbo, zb: zb, kinder: kinder) + partnerZve,
                                             spl: spl, fuenftel: false, abf: 0, kinder: kinder).total
        let taxSalTurbo = TaxMath.totalTax(zve: TaxMath.employmentZve(bgTurbo, zb: zb, kinder: kinder) + partnerZve,
                                           spl: spl, fuenftel: false, abf: 0, kinder: kinder).total
        let netSalNoTurbo = bgNoTurbo - sozNoTurbo - taxSalNoTurbo
        let netSalTurbo = bgTurbo - TaxMath.sozAbzug(bgTurbo, zb: zb, kinder: kinder) - taxSalTurbo
        let lostNetSalary = max(0, netSalNoTurbo - netSalTurbo)

        let taxTurboBase = TaxMath.totalTax(zve: zveAfterAllTurboSim, spl: spl, fuenftel: true, abf: barNoTurbo, kinder: kinder).total
        let wealthTurboBase = (bgTurbo - TaxMath.sozAbzug(bgTurbo, zb: zb, kinder: kinder))
            + max(0, abfNoTurbo - bav - drvRaw) - taxTurboBase
        let pureFuenftel = max(0, (wealthTurboBase - wealthNoTurbo) + lostNetSalary)

        let fullTurboAbf = abfNoTurbo + fristD * alt * turboFaktor
        let barFullTurbo = max(0, fullTurboAbf - bav - drvTaxFree)
        let taxTurboFull = TaxMath.totalTax(zve: zveAfterAllTurboSim, spl: spl, fuenftel: true, abf: barFullTurbo, kinder: kinder).total
        let extraTaxOnPremium = max(0, taxTurboFull - taxTurboBase)
        let isolatedNettoPraemie = max(0, (fullTurboAbf - abfNoTurbo) - extraTaxOnPremium)

        let rvSim = fristD * min(alt, Const.bbgRVMonat) * 0.186
        let alg1Sim = i.includeAlg1Loss ? Double(min(3, frist)) * alg1Monat : 0
        let gains = isolatedNettoPraemie + pureFuenftel
        let losses = lostNetSalary + gkvTurboSim + rvSim + alg1Sim
        r.isolatedNettoPraemie = isolatedNettoPraemie
        r.pureFuenftelAdvantage = pureFuenftel
        r.lostNetSalary = lostNetSalary
        r.gkvTurboSim = gkvTurboSim
        r.rvSim = rvSim
        r.alg1Sim = alg1Sim
        r.sprinterGains = gains
        r.sprinterLosses = losses
        r.sprinterNetDiff = gains - losses

        // Arbeitgeber-Lohnsteuer-Einbehalt & Finanzamt
        let agZve = TaxMath.employmentZve(agFiktiv, zb: zb, kinder: kinder) + partnerZve
        let taxG = TaxMath.totalTax(zve: agZve, spl: spl, fuenftel: false, abf: 0, kinder: kinder).total
        let taxVoll = TaxMath.totalTax(zve: agZve + barTaxable, spl: spl, fuenftel: false, abf: 0, kinder: kinder).total
        let einbehalten = max(0, taxVoll - taxG)
        let netVoll = max(0, barCash - einbehalten)
        r.rateUpfront = barTaxable > 0 ? einbehalten / barTaxable * 100 : 0

        let taxNoBavDrv = TaxMath.totalTax(zve: agZve + effAbf, spl: spl, fuenftel: false, abf: 0, kinder: kinder).total
        let upfrontSavedBavDrv = max(0, taxNoBavDrv - taxVoll)
        let upfrontSavedBav = (bav + drvTaxFree) > 0 ? upfrontSavedBavDrv * (bav / (bav + drvTaxFree)) : 0

        let taxPaidBasePayroll = TaxMath.totalTax(zve: TaxMath.employmentZve(bg, zb: zb, kinder: kinder) + partnerZve,
                                                  spl: spl, fuenftel: false, abf: 0, kinder: kinder).total
        let netGehaltBase = bg - sozRegular - taxPaidBasePayroll

        let totalPaidYear = taxPaidBasePayroll + einbehalten
        let T0 = TaxMath.totalTax(zve: zveBasisActive, spl: spl, fuenftel: true, abf: effAbf, kinder: kinder).total
        let T1 = TaxMath.totalTax(zve: zveBasisActive, spl: spl, fuenftel: true, abf: barTaxable, kinder: kinder).total
        let erst = max(0, totalPaidYear - T3)

        let bavAndDrvSavings = max(0, T0 - T1)
        let drvOnlyBase = max(0, effAbf - drvTaxFree)
        let tDrvOnly = TaxMath.totalTax(zve: zveBasisActive, spl: spl, fuenftel: true, abf: drvOnlyBase, kinder: kinder).total
        let bavOnlyBase = max(0, effAbf - bav)
        let tBavOnly = TaxMath.totalTax(zve: zveBasisActive, spl: spl, fuenftel: true, abf: bavOnlyBase, kinder: kinder).total
        let sBav = max(0, T0 - tBavOnly)
        let sDrv = max(0, T0 - tDrvOnly)
        let drvTotalErsparnis = (sBav + sDrv) > 0 ? bavAndDrvSavings * (sDrv / (sBav + sDrv)) : 0

        let taxWithoutDrvTaxable = TaxMath.totalTax(zve: zveAfterAll, spl: spl, fuenftel: true,
                                                    abf: max(0, barTaxable - drvTaxable), kinder: kinder).total
        let taxWithoutDrvTaxableNoFf = TaxMath.totalTax(zve: zveAfterAll, spl: spl, fuenftel: false,
                                                        abf: max(0, barTaxable - drvTaxable), kinder: kinder).total
        let taxWithDrvTaxableNoFf = TaxMath.totalTax(zve: zveAfterAll, spl: spl, fuenftel: false, abf: barTaxable, kinder: kinder).total
        let drvFuenftelRefund = drvTaxable > 0
            ? max(0, (taxWithDrvTaxableNoFf - taxWithoutDrvTaxableNoFf) - (T3 - taxWithoutDrvTaxable))
            : 0

        let combinedOptSavings = max(0, T1 - T3)
        let standaloneRuerup = max(0, T1 - TaxMath.totalTax(zve: zveBasisActive - ruerup, spl: spl, fuenftel: true, abf: barTaxable, kinder: kinder).total)
        let standaloneIab = max(0, T1 - TaxMath.totalTax(zve: zveBasisActive - iab, spl: spl, fuenftel: true, abf: barTaxable, kinder: kinder).total)
        let standaloneSum = standaloneRuerup + standaloneIab
        let ruerupErsparnis = standaloneSum > 0 ? combinedOptSavings * (standaloneRuerup / standaloneSum) : 0
        let iabErsparnis = standaloneSum > 0 ? combinedOptSavings * (standaloneIab / standaloneSum) : 0

        let taxBaseAfterAll = TaxMath.totalTax(zve: zveAfterAll, spl: spl, fuenftel: false, abf: 0, kinder: kinder).total
        let finalAbfTax = max(0, T3 - taxBaseAfterAll)
        let netFf = max(0, barCash - finalAbfTax)
        r.rateFinal = barTaxable > 0 ? finalAbfTax / barTaxable * 100 : 0

        r.bavSaving = OptSaving(amount: bav, savings: upfrontSavedBav)
        r.drvSaving = OptSaving(amount: drvRaw, savings: drvTotalErsparnis)
        r.ruerupSaving = OptSaving(amount: ruerup, savings: ruerupErsparnis)
        r.iabSaving = OptSaving(amount: iabInvest, savings: iabErsparnis)

        if i.splitting {
            let userZve = TaxMath.employmentZve(bg, zb: zb, kinder: kinder) - gkvPenalty2027 - iab - ruerup
            let maxPartner = TaxMath.maxPartnerGrossForSplitting(userZve: userZve, taxableAbf: barTaxable, kinder: kinder, zb: zb)
            // The HTML subtracts ruerup/2 from each partner for the single-assessment comparison; kept identical.
            let userZveHalf = TaxMath.employmentZve(bg, zb: zb, kinder: kinder) - gkvPenalty2027 - iab - ruerup / 2
            let vSingle = TaxMath.totalTax(zve: userZveHalf, spl: 1, fuenftel: true, abf: barTaxable, kinder: kinder).total
                + TaxMath.totalTax(zve: TaxMath.employmentZve(pGehalt, zb: zb, kinder: kinder) - ruerup / 2, spl: 1, fuenftel: false, abf: 0, kinder: kinder).total
            r.splitting = SplittingInfo(maxPartnerGross: maxPartner, advantage: vSingle - T3)
        }

        let liq27 = netVoll + netGehaltBase - ruerup - iabInvest - gkvPenalty2027
        let liq28 = liq27 + erst

        r.netVoll = netVoll
        r.erstattung = erst
        r.netFf = netFf
        r.liq27 = liq27
        r.liq28 = liq28
        r.abfNoTurbo = abfNoTurbo
        r.praemieBrutto = praemieBrutto
        r.effectiveAbfindung = effAbf
        r.barBruttoTaxable = barTaxable
        r.barBruttoCash = barCash
        r.einbehalten = einbehalten
        r.zveAfterAll = zveAfterAll
        r.finalAbfTax = finalAbfTax
        r.netGehaltBase = netGehaltBase
        r.drvFuenftelRefund2028 = drvFuenftelRefund
        r.baseFuenftelRefund = max(0, erst - drvFuenftelRefund - ruerupErsparnis - iabErsparnis)

        let ctx = SimCtx(altesMonatsgehalt: alt, preMonths: preMonths, fristMonate: frist, abfNoTurbo: abfNoTurbo,
                         turboFaktor: turboFaktor, agZveBasis: agZve, spl: spl, pGehalt: pGehalt,
                         partnerZveBasis: partnerZve, zb: zb, kinder: kinder, bav: bav, drvRaw: drvRaw,
                         drvTaxFree: drvTaxFree, ruerup: ruerup, iab: iab, iabInvest: iabInvest,
                         gkvHoechstsatzMonat: gkvHoechst, gkvMinMonat: gkvMin, alg1Monat: alg1Monat,
                         preExitGkvPflicht: i.preExitGkvPflicht)
        r.ctx = ctx
        r.runwayStd = Runway.simulate(ctx, i, sprinter: false)
        r.runwaySpr = Runway.simulate(ctx, i, sprinter: true)

        let newMonthly = i.crossoverPerYear ? max(0, i.crossoverNewGross) / 12 : max(0, i.crossoverNewGross)
        let delay = max(0, i.crossoverDelayMonths)
        let growth = i.crossoverGrowth / 100
        let cStd = Crossover.simulate(ctx, i, sprinter: false, newMonthlyGross: newMonthly, delay: delay, growth: growth)
        let cSpr = Crossover.simulate(ctx, i, sprinter: true, newMonthlyGross: newMonthly, delay: delay, growth: growth)
        r.crossStd = cStd
        r.crossSpr = cSpr
        r.crossMonthlyLoss = max(0, cStd.baseOldNet - cStd.baseNewNet)
        return r
    }
}
