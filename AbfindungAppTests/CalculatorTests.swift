import XCTest
@testable import AbfindungApp

/// Regression tests.
/// Scenario expectations (`testScenario_*`) were captured by running a copy of the original HTML calculator,
/// patched with the 2027 draft tariff (BT-Drucksache 21/8235) and the agreed rule changes, in a headless browser.
/// They guard the Swift port against transcription errors. Tariff and rule tests below use hand-calculated values.
final class CalculatorTests: XCTestCase {

    // The assertions on labels and number formats expect German.
    override func setUp() {
        super.setUp()
        Lang.shared.code = "de"
    }

    private func eur(_ actual: Double, _ expected: Int, _ name: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual, Double(expected), accuracy: 1.5, name, file: file, line: line)
    }

    /// Default inputs with the Pro sections C and D switched on (the scenarios below check their results).
    private func scenario() -> Inputs {
        var i = Inputs()
        i.runwayEnabled = true
        i.crossoverEnabled = true
        return i
    }

    private func label(_ r: CrossoverResult?) -> String {
        r?.breakevenMonthFromJan27.map(monthLabel) ?? "nie"
    }

    func testScenario_Default() {
        var i = scenario()
        let r = Calculator.compute(i)
        eur(r.netVoll, 82756, "Sofort-Netto")
        eur(r.erstattung, 11294, "Erstattung/Nachzahlung")
        eur(r.netFf, 92447, "Optimal-Netto")
        eur(r.liq28, 129939, "Konto Ende 2028")
        eur(r.sprinterNetDiff, 30065, "Sprinter-Bilanz")
        eur(r.isolatedNettoPraemie, 34358, "Netto-Praemie")
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 48, "Reichweite Standard")
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 52, "Reichweite Sprinter")
        eur(r.runwaySpr?.faRefundOct2028 ?? 0, 41696, "Runway FA")
        XCTAssertEqual(label(r.crossStd), "Mai 2036")
        XCTAssertEqual(label(r.crossSpr), "Okt 2038")
        eur(r.crossMonthlyLoss, 766, "Netto-Einbusse")
    }

    func testScenario_SprinterOpt() {
        var i = scenario()
        i.isTurbo = true
        i.optEnabled = true
        i.bav = 42500
        i.ruerup = 10000
        let r = Calculator.compute(i)
        eur(r.netVoll, 88325, "Sofort-Netto")
        eur(r.erstattung, 48179, "Erstattung/Nachzahlung")
        eur(r.netFf, 136031, "Optimal-Netto")
        eur(r.liq28, 137209, "Konto Ende 2028")
        eur(r.sprinterNetDiff, 28414, "Sprinter-Bilanz")
        eur(r.isolatedNettoPraemie, 38076, "Netto-Praemie")
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 39, "Reichweite Standard")
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 43, "Reichweite Sprinter")
        eur(r.runwaySpr?.faRefundOct2028 ?? 0, 40733, "Runway FA")
        XCTAssertEqual(label(r.crossStd), "Nov 2033")
        XCTAssertEqual(label(r.crossSpr), "Jul 2036")
        eur(r.crossMonthlyLoss, 766, "Netto-Einbusse")
    }

    func testScenario_SplittingKist9() {
        var i = scenario()
        i.splitting = true
        i.kinder = 1
        i.kirchensteuer = 0.09
        let r = Calculator.compute(i)
        eur(r.netVoll, 78543, "Sofort-Netto")
        eur(r.erstattung, 19933, "Erstattung/Nachzahlung")
        eur(r.netFf, 98476, "Optimal-Netto")
        eur(r.liq28, 127958, "Konto Ende 2028")
        eur(r.sprinterNetDiff, 15222, "Sprinter-Bilanz")
        eur(r.isolatedNettoPraemie, 33579, "Netto-Praemie")
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 47, "Reichweite Standard")
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 51, "Reichweite Sprinter")
        eur(r.runwaySpr?.faRefundOct2028 ?? 0, 53132, "Runway FA")
        XCTAssertEqual(label(r.crossStd), "Mai 2037")
        XCTAssertEqual(label(r.crossSpr), "Nov 2039")
        eur(r.crossMonthlyLoss, 726, "Netto-Einbusse")
    }

    func testScenario_SprinterKist8Minijob() {
        var i = scenario()
        i.isTurbo = true
        i.kinder = 0
        i.alg1Satz = 0.6
        i.kirchensteuer = 0.08
        i.includeAlg1Loss = true
        i.runwayMinijob = 300
        i.runwayRealReturn = 2
        i.runwayCapRuerupSweetSpot = false
        let r = Calculator.compute(i)
        eur(r.netVoll, 104471, "Sofort-Netto")
        eur(r.erstattung, 38811, "Erstattung/Nachzahlung")
        eur(r.netFf, 142810, "Optimal-Netto")
        eur(r.liq28, 153570, "Konto Ende 2028")
        eur(r.sprinterNetDiff, 19086, "Sprinter-Bilanz")
        eur(r.isolatedNettoPraemie, 32540, "Netto-Praemie")
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 48, "Reichweite Standard")
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 54, "Reichweite Sprinter")
        eur(r.runwaySpr?.faRefundOct2028 ?? 0, 41580, "Runway FA")
        XCTAssertEqual(label(r.crossStd), "Okt 2036")
        XCTAssertEqual(label(r.crossSpr), "Okt 2039")
        eur(r.crossMonthlyLoss, 726, "Netto-Einbusse")
    }

    func testScenario_NegativeBase() {
        var i = scenario()
        i.isTurbo = true
        i.optEnabled = true
        i.ruerup = 20000
        i.iabInvest = 100000
        let r = Calculator.compute(i)
        eur(r.netVoll, 111394, "Sofort-Netto")
        eur(r.erstattung, 72804, "Erstattung/Nachzahlung")
        eur(r.netFf, 183725, "Optimal-Netto")
        eur(r.liq28, 74903, "Konto Ende 2028")
        eur(r.sprinterNetDiff, 7867, "Sprinter-Bilanz")
        eur(r.isolatedNettoPraemie, 38940, "Netto-Praemie")
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 55, "Reichweite Standard")
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 56, "Reichweite Sprinter")
        eur(r.runwaySpr?.faRefundOct2028 ?? 0, 59352, "Runway FA")
        XCTAssertEqual(label(r.crossStd), "Mai 2040")
        XCTAssertEqual(label(r.crossSpr), "Apr 2043")
        eur(r.crossMonthlyLoss, 766, "Netto-Einbusse")
    }

    func testScenario_LateStart() {
        var i = scenario()
        i.startMonth = 10
        let r = Calculator.compute(i)
        eur(r.netVoll, 82756, "Sofort-Netto")
        eur(r.erstattung, 2685, "Erstattung/Nachzahlung")
        eur(r.netFf, 83439, "Optimal-Netto")
        eur(r.liq28, 135673, "Konto Ende 2028")
        eur(r.sprinterNetDiff, 17280, "Sprinter-Bilanz")
        eur(r.isolatedNettoPraemie, 29237, "Netto-Praemie")
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 49, "Reichweite Standard")
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 50, "Reichweite Sprinter")
        eur(r.runwaySpr?.faRefundOct2028 ?? 0, 11241, "Runway FA")
        XCTAssertEqual(label(r.crossStd), "Sep 2036")
        XCTAssertEqual(label(r.crossSpr), "Jan 2039")
        eur(r.crossMonthlyLoss, 766, "Netto-Einbusse")
    }

    func testScenario_Nachzahlung() {
        var i = scenario()
        i.agFiktivGehalt = 0
        i.agFiktivAuto = false
        i.kinder = 0
        let r = Calculator.compute(i)
        eur(r.netVoll, 95395, "Sofort-Netto")
        eur(r.erstattung, -5422, "Erstattung/Nachzahlung")
        eur(r.netFf, 89973, "Optimal-Netto")
        eur(r.liq28, 125523, "Konto Ende 2028")
        eur(r.sprinterNetDiff, 25744, "Sprinter-Bilanz")
        eur(r.isolatedNettoPraemie, 33934, "Netto-Praemie")
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 47, "Reichweite Standard")
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 51, "Reichweite Sprinter")
        eur(r.runwaySpr?.faRefundOct2028 ?? 0, 24739, "Runway FA")
        XCTAssertEqual(label(r.crossStd), "Feb 2036")
        XCTAssertEqual(label(r.crossSpr), "Jul 2038")
        eur(r.crossMonthlyLoss, 764, "Netto-Einbusse")
    }

    func testScenario_ManyKidsDrv() {
        var i = scenario()
        i.isTurbo = true
        i.kinder = 2.5
        i.zusatzbeitrag = 3.5
        i.optEnabled = true
        i.bav = 20000
        i.drv = 30000
        let r = Calculator.compute(i)
        eur(r.netVoll, 77960, "Sofort-Netto")
        eur(r.erstattung, 53384, "Erstattung/Nachzahlung")
        eur(r.netFf, 130863, "Optimal-Netto")
        eur(r.liq28, 141930, "Konto Ende 2028")
        eur(r.sprinterNetDiff, 26188, "Sprinter-Bilanz")
        eur(r.isolatedNettoPraemie, 38453, "Netto-Praemie")
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 41, "Reichweite Standard")
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 44, "Reichweite Sprinter")
        eur(r.runwaySpr?.faRefundOct2028 ?? 0, 45937, "Runway FA")
        XCTAssertEqual(label(r.crossStd), "Jul 2034")
        XCTAssertEqual(label(r.crossSpr), "Apr 2037")
        eur(r.crossMonthlyLoss, 766, "Netto-Einbusse")
    }

    func testScenario_HighEarner() {
        var i = scenario()
        i.altesMonatsgehalt = 15000
        i.bruttoAbfindung = 400000
        i.startMonth = 6
        i.fristMonate = 6
        i.isTurbo = true
        i.agFiktivGehalt = 180000
        i.agFiktivAuto = false
        i.optEnabled = true
        i.bav = 50500
        let r = Calculator.compute(i)
        eur(r.netVoll, 249622, "Sofort-Netto")
        eur(r.erstattung, 28943, "Erstattung/Nachzahlung")
        eur(r.netFf, 274343, "Optimal-Netto")
        eur(r.liq28, 317331, "Konto Ende 2028")
        eur(r.sprinterNetDiff, 17582, "Sprinter-Bilanz")
        eur(r.isolatedNettoPraemie, 75182, "Netto-Praemie")
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 94, "Reichweite Standard")
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 101, "Reichweite Sprinter")
        eur(r.runwaySpr?.faRefundOct2028 ?? 0, 55859, "Runway FA")
        XCTAssertEqual(label(r.crossStd), "Feb 2031")
        XCTAssertEqual(label(r.crossSpr), "Okt 2031")
        eur(r.crossMonthlyLoss, 5036, "Netto-Einbusse")
    }


    // MARK: Rule tests (hand-calculated)

    func testDraftTariff2027() {
        XCTAssertEqual(TaxMath.est(12_564, 1), 0)
        XCTAssertEqual(TaxMath.est(-5, 1), 0)
        XCTAssertEqual(TaxMath.est(15_000, 1), 397)
        XCTAssertEqual(TaxMath.est(18_000, 1), 1_042)
        XCTAssertEqual(TaxMath.est(50_000, 1), 10_482)
        XCTAssertEqual(TaxMath.est(100_000, 1), 30_758)
        XCTAssertEqual(TaxMath.est(250_000, 1), 93_758)
        XCTAssertEqual(TaxMath.est(300_000, 1), 116_658)
        XCTAssertEqual(TaxMath.est(100_000, 2), 2 * TaxMath.est(50_000, 1))
        // zone borders join up (at most 1 EUR rounding)
        XCTAssertLessThanOrEqual(abs(TaxMath.est(17_800, 1) - TaxMath.est(17_799, 1)), 1)
        XCTAssertLessThanOrEqual(abs(TaxMath.est(70_601, 1) - TaxMath.est(70_600, 1)), 1)
        XCTAssertLessThanOrEqual(abs(TaxMath.est(250_000, 1) - TaxMath.est(249_999, 1)), 1)
        XCTAssertLessThanOrEqual(abs(TaxMath.est(280_000, 1) - TaxMath.est(279_999, 1)), 1)
    }

    func testSoliFreigrenze() {
        XCTAssertEqual(TaxMath.soli(20_350, 1), 0)
        XCTAssertEqual(TaxMath.soli(30_000, 1), (30_000 - 20_350) * 0.119, accuracy: 0.001)
        XCTAssertEqual(TaxMath.soli(40_700, 2), 0)
        XCTAssertEqual(TaxMath.soli(100_000, 1), 5_500, accuracy: 0.001)
    }

    func testNegativeBaseIsOffsetAgainstAbfindung() {
        // § 34 Abs. 1 Satz 3 EStG: 5 x tax on (100.000 - 10.000) / 5 = 5 x est(18.000)
        let t = TaxMath.totalTax(zve: -10_000, spl: 1, fuenftel: true, abf: 100_000)
        XCTAssertEqual(t.est, 5_210)
        // negative base larger than the Abfindung -> no tax
        XCTAssertEqual(TaxMath.totalTax(zve: -150_000, spl: 1, fuenftel: true, abf: 100_000).total, 0)
    }

    func testWithholdingIgnoresKinderfreibetragForLohnsteuer() {
        let noKids = TaxCtx(spl: 1, kinder: 0, kist: 0).withholding(60_000)
        let kids = TaxCtx(spl: 1, kinder: 1, kist: 0.09).withholding(60_000)
        XCTAssertEqual(kids.lst, noKids.lst)                    // Lohnsteuer itself unchanged
        XCTAssertLessThan(kids.soli, noKids.soli + 0.001)       // Soli uses the reduced tax
        XCTAssertEqual(kids.kist, 0.09 * TaxMath.est(60_000 - 10_056, 1), accuracy: 0.001)
    }

    func testKirchensteuerLowersNetResult() {
        var i = Inputs()
        let base = Calculator.compute(i)
        i.kirchensteuer = 0.08
        let bayern = Calculator.compute(i)
        i.kirchensteuer = 0.09
        let other = Calculator.compute(i)
        XCTAssertLessThan(bayern.netFf, base.netFf)
        XCTAssertLessThan(other.netFf, bayern.netFf)
        XCTAssertLessThan(other.netVoll, bayern.netVoll)
        XCTAssertGreaterThan(other.kistWithheld, 0)
        XCTAssertGreaterThan(other.kistFinal, 0)
        XCTAssertEqual(base.kistFinal, 0)
    }

    func testNachzahlungIsNotHidden() {
        var i = Inputs()
        i.agFiktivGehalt = 0
        i.agFiktivAuto = false
        i.kinder = 0
        XCTAssertLessThan(Calculator.compute(i).erstattung, 0)
    }

    func testPflegeversicherungCautiousRates() {
        XCTAssertEqual(TaxMath.pvRate(0), 0.027, accuracy: 1e-9)       // 1,8 % + 0,9 Kinderlosenzuschlag
        XCTAssertEqual(TaxMath.pvRate(0.5), 0.018, accuracy: 1e-9)
        XCTAssertEqual(TaxMath.pvRate(2), 0.0155, accuracy: 1e-9)      // minus 0,25 Punkte ab dem 2. Kind
        XCTAssertEqual(TaxMath.pvRate(6), 0.008, accuracy: 1e-9)       // Abschlag nur bis zum 5. Kind
        XCTAssertEqual(TaxMath.gkvHoechstsatzMonat(2.9, kinder: 1), 6_375 * 0.211, accuracy: 0.001)
        XCTAssertEqual(TaxMath.gkvHoechstsatzMonat(2.9, kinder: 0), 6_375 * 0.220, accuracy: 0.001)
    }

    func testRuhenszeitAndSperrzeit() {
        XCTAssertEqual(Calculator.ruhensMonths(abfindung: 202_500, monthly: 7_000, frist: 5, anteil: 0.6), 5)
        XCTAssertEqual(Calculator.ruhensMonths(abfindung: 20_000, monthly: 7_000, frist: 5, anteil: 0.6), 2)
        XCTAssertEqual(Calculator.ruhensMonths(abfindung: 1_000_000, monthly: 7_000, frist: 18, anteil: 0.6), 12)
        XCTAssertEqual(Calculator.sperrzeitMonths(alg1Months: 12), 3)
        XCTAssertEqual(Calculator.sperrzeitMonths(alg1Months: 18), 5)
        XCTAssertEqual(Calculator.sperrzeitMonths(alg1Months: 0), 0)
    }

    func testPayoutStaysIn2027() {
        var i = scenario()
        i.startMonth = 12
        i.fristMonate = 6
        let r = Calculator.compute(i)
        XCTAssertEqual(r.salMonthsStd, 12)
        XCTAssertEqual(r.runwayStd?.salMonthsTotal, 17)   // salary phase continues, Abfindung taxed/paid in 2027
        XCTAssertGreaterThan(r.netVoll, 0)
    }

    func testFormatting() {
        XCTAssertEqual(Fmt.eur(1_234_567.4), "1.234.567 €")
        XCTAssertEqual(Fmt.eur(0), "0 €")
        XCTAssertEqual(Fmt.signedEur(-1500), "− 1.500 €")
    }

    func testPresetKeepsIntendedBavValue() {
        let model = AppModel(inputs: Inputs(), isPro: true)
        model.apply(.sprinterSweet)
        XCTAssertEqual(model.inputs.bav, 42_480)
        XCTAssertTrue(model.inputs.isTurbo)
        XCTAssertTrue(model.inputs.optEnabled)
        XCTAssertGreaterThan(model.inputs.ruerup, 0)
    }

    // MARK: Basic / Pro

    func testBasicIgnoresStoredProInputs() {
        var proInputs = Inputs()
        proInputs.optEnabled = true
        proInputs.bav = 40_000
        proInputs.drv = 20_000
        proInputs.ruerup = 10_000
        proInputs.iabInvest = 100_000
        proInputs.runwayEnabled = true
        proInputs.crossoverEnabled = true
        let basic = Calculator.compute(proInputs, pro: false)
        let plain = Calculator.compute(Inputs(), pro: true)
        eur(basic.netVoll, Int(plain.netVoll.rounded()), "Sofort-Netto")
        eur(basic.erstattung, Int(plain.erstattung.rounded()), "Erstattung")
        eur(basic.netFf, Int(plain.netFf.rounded()), "Optimal-Netto")
        XCTAssertEqual(basic.bav, 0)
        XCTAssertEqual(basic.drvRaw, 0)
        XCTAssertEqual(basic.ruerup, 0)
        XCTAssertEqual(basic.iabInvest, 0)
        XCTAssertNil(basic.runwayStd)
        XCTAssertNil(basic.crossStd)
    }

    func testProSectionsOnlyCalculateWhenSwitchedOn() {
        let off = Calculator.compute(Inputs(), pro: true)
        XCTAssertNil(off.runwayStd)
        XCTAssertNil(off.runwaySpr)
        XCTAssertNil(off.crossStd)
        XCTAssertNil(off.crossSpr)
        var on = Inputs()
        on.runwayEnabled = true
        let onlyRunway = Calculator.compute(on, pro: true)
        XCTAssertNotNil(onlyRunway.runwayStd)
        XCTAssertNil(onlyRunway.crossStd)
        on.crossoverEnabled = true
        XCTAssertNotNil(Calculator.compute(on, pro: true).crossStd)
    }

    func testBasicModelBlocksProActions() {
        let model = AppModel(inputs: Inputs(), isPro: false)
        AppSheets.shared.showUnlock = false
        model.setOptEnabled(true)
        XCTAssertFalse(model.inputs.optEnabled)
        XCTAssertTrue(AppSheets.shared.showUnlock)
        AppSheets.shared.showUnlock = false
        model.apply(.runwayCheck)
        XCTAssertFalse(model.inputs.runwayEnabled)
        XCTAssertFalse(model.inputs.isTurbo)
        XCTAssertTrue(AppSheets.shared.showUnlock)
        AppSheets.shared.showUnlock = false
        model.applyRuerupSweetSpot()
        XCTAssertEqual(model.inputs.ruerup, 0)
    }

    func testReset() {
        let model = AppModel(inputs: Inputs(), isPro: false)
        model.inputs.isTurbo = true
        model.apply(.reset)
        XCTAssertEqual(model.inputs, Inputs())
    }

    func testProModelEnablesSections() {
        let model = AppModel(inputs: Inputs(), isPro: true)
        model.apply(.runwayCheck)
        XCTAssertTrue(model.inputs.runwayEnabled)
        XCTAssertNotNil(model.results.runwayStd)
        XCTAssertEqual(model.selectedTab, .runway)
        model.apply(.gehaltsSwitch)
        XCTAssertTrue(model.inputs.crossoverEnabled)
        XCTAssertNotNil(model.results.crossStd)
        model.isPro = false
        XCTAssertNil(model.results.runwayStd)
        XCTAssertNil(model.results.crossStd)
    }

    // MARK: Automatic employer salary

    func testNotionalEmployerSalaryFollowsMonthlySalary() {
        var auto = Inputs()
        auto.altesMonatsgehalt = 10_000
        var manual = auto
        manual.agFiktivAuto = false
        manual.agFiktivGehalt = 120_000
        var stale = auto
        stale.agFiktivAuto = false
        stale.agFiktivGehalt = 84_000
        let a = Calculator.compute(auto)
        let m = Calculator.compute(manual)
        let s = Calculator.compute(stale)
        XCTAssertEqual(a.netVoll, m.netVoll, accuracy: 0.5)
        XCTAssertEqual(a.erstattung, m.erstattung, accuracy: 0.5)
        XCTAssertNotEqual(a.netVoll, s.netVoll)   // a stale 84.000 € would give a different withholding
    }
}
