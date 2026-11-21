import XCTest
@testable import AbfindungApp

/// Expected values were captured by running the original `rechner_pro_v26_9.html`
/// in a headless browser, so these tests guard the Swift port against drift.
final class CalculatorTests: XCTestCase {

    private func assertEur(_ actual: Double, _ expected: Double, _ name: String,
                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: 1.0, name, file: file, line: line)
    }

    private func label(_ r: CrossoverResult) -> String {
        r.breakevenMonthFromJan27.map(monthLabel) ?? "nie"
    }

    func testDefaultScenario() {
        let r = Calculator.compute(Inputs())
        assertEur(r.netVoll, 82_882, "Sofort-Netto")
        assertEur(r.erstattung, 11_310, "FA-Erstattung")
        assertEur(r.netFf, 94_192, "Optimal-Netto")
        assertEur(r.liq28, 129_947, "Konto Ende 2028")
        XCTAssertEqual(r.rateFinal, 37.2, accuracy: 0.05)
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 48)
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 52)
        assertEur(r.runwaySpr?.faRefundOct2028 ?? 0, 41_007, "Runway FA-Erstattung")
        XCTAssertEqual(label(r.crossStd!), "Dez 2035")
        XCTAssertEqual(label(r.crossSpr!), "Mai 2038")
        assertEur(r.crossMonthlyLoss, 787, "Netto-Einbuße")
        assertEur(r.sprinterNetDiff, 30_133, "Sprinter-Bilanz")
        assertEur(r.isolatedNettoPraemie, 34_468, "Netto-Prämie")
    }

    func testSprinterSweetSpotPreset() {
        let model = AppModel(inputs: Inputs())
        model.apply(.sprinterSweet)
        XCTAssertEqual(model.inputs.ruerup, 10_000)
        let r = model.results
        assertEur(r.netVoll, 88_451, "Sofort-Netto")
        assertEur(r.erstattung, 55_334, "FA-Erstattung")
        assertEur(r.netFf, 143_330, "Optimal-Netto")
        assertEur(r.liq28, 144_526, "Konto Ende 2028")
        XCTAssertEqual(r.rateFinal, 10.4, accuracy: 0.05)
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 39)
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 45)
        assertEur(r.runwaySpr?.faRefundOct2028 ?? 0, 48_212, "Runway FA-Erstattung")
        XCTAssertEqual(label(r.crossStd!), "Jul 2033")
        XCTAssertEqual(label(r.crossSpr!), "Feb 2036")
        assertEur(r.sprinterNetDiff, 35_792, "Sprinter-Bilanz")
        assertEur(r.isolatedNettoPraemie, 39_305, "Netto-Prämie")
    }

    func testSplittingTariff() {
        var i = Inputs()
        i.splitting = true
        let r = Calculator.compute(i)
        assertEur(r.netVoll, 84_320, "Sofort-Netto")
        assertEur(r.erstattung, 15_301, "FA-Erstattung")
        assertEur(r.netFf, 99_622, "Optimal-Netto")
        assertEur(r.liq28, 129_998, "Konto Ende 2028")
        XCTAssertEqual(r.rateFinal, 33.6, accuracy: 0.05)
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 48)
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 52)
        assertEur(r.runwaySpr?.faRefundOct2028 ?? 0, 45_860, "Runway FA-Erstattung")
        XCTAssertEqual(label(r.crossStd!), "Aug 2036")
        XCTAssertEqual(label(r.crossSpr!), "Mär 2039")
        assertEur(r.sprinterNetDiff, 14_993, "Sprinter-Bilanz")
        XCTAssertNotNil(r.splitting)
    }

    func testSprinterNoKidsWithMinijobAndRealReturn() {
        var i = Inputs()
        i.isTurbo = true
        i.kinder = 0
        i.alg1Satz = 0.60
        i.runwayCapRuerupSweetSpot = false
        i.runwayMinijob = 300
        i.runwayRealReturn = 2
        let r = Calculator.compute(i)
        assertEur(r.netVoll, 111_905, "Sofort-Netto")
        assertEur(r.erstattung, 35_064, "FA-Erstattung")
        assertEur(r.netFf, 146_538, "Optimal-Netto")
        assertEur(r.liq28, 157_608, "Konto Ende 2028")
        XCTAssertEqual(r.rateFinal, 27.6, accuracy: 0.05)
        XCTAssertEqual(r.runwayStd?.exhaustedMonth, 50)
        XCTAssertEqual(r.runwaySpr?.exhaustedMonth, 56)
        assertEur(r.runwaySpr?.faRefundOct2028 ?? 0, 37_934, "Runway FA-Erstattung")
        XCTAssertEqual(label(r.crossStd!), "Nov 2036")
        XCTAssertEqual(label(r.crossSpr!), "Nov 2039")
        assertEur(r.crossMonthlyLoss, 764, "Netto-Einbuße")
        assertEur(r.sprinterNetDiff, 25_556, "Sprinter-Bilanz")
        assertEur(r.isolatedNettoPraemie, 34_020, "Netto-Prämie")
    }

    func testTaxTariffBoundaries() {
        XCTAssertEqual(TaxMath.est(12_564, 1), 0)
        XCTAssertEqual(TaxMath.est(-5, 1), 0)
        XCTAssertGreaterThan(TaxMath.est(70_601, 1), 0)
        XCTAssertEqual(TaxMath.est(50_000, 2), TaxMath.est(25_000, 1) * 2)
    }

    func testFormatting() {
        XCTAssertEqual(Fmt.eur(1_234_567.4), "1.234.567 €")
        XCTAssertEqual(Fmt.eur(0), "0 €")
        XCTAssertEqual(Fmt.signedEur(-1500), "− 1.500 €")
    }
}
