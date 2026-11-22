import XCTest
@testable import AbfindungApp

final class LocalizationTests: XCTestCase {

    override func tearDown() {
        Lang.shared.code = "de"
        super.tearDown()
    }

    func testGermanIsTheKey() {
        Lang.shared.code = "de"
        XCTAssertEqual(tr("Reichweite"), "Reichweite")
        XCTAssertEqual(tr("Jahresbrutto: \(Fmt.eur(84_000))"), "Jahresbrutto: 84.000 €")
    }

    func testEnglishTranslationAndInterpolation() {
        Lang.shared.code = "en"
        XCTAssertEqual(tr("Reichweite"), "Runway")
        XCTAssertEqual(tr("Jahresbrutto: \(Fmt.eur(84_000))"), "Annual gross: 84,000 €")
        XCTAssertEqual(tr("Sprinter: \(3)M Gehalt | Standard: \(8)M Gehalt"), "Sprinter: 3 mo. salary | Standard: 8 mo. salary")
        // unknown text falls back to the German original
        XCTAssertEqual(tr("Nicht übersetzt"), "Nicht übersetzt")
    }

    func testPercentSignsInTextsAreKept() {
        Lang.shared.code = "en"
        XCTAssertEqual(tr("50 % steuerfrei (§ 3 Nr. 28 EStG)"), "50 % tax-free (§ 3 Nr. 28 EStG)")
        Lang.shared.code = "de"
        XCTAssertEqual(tr("50 % steuerfrei (§ 3 Nr. 28 EStG)"), "50 % steuerfrei (§ 3 Nr. 28 EStG)")
    }

    func testEveryEnglishTextKeepsTheSamePlaceholders() {
        for (german, english) in L10n.en {
            XCTAssertEqual(german.components(separatedBy: "%@").count, english.components(separatedBy: "%@").count,
                           "placeholder mismatch: \(german)")
            XCTAssertFalse(english.isEmpty, "empty translation: \(german)")
        }
    }

    func testNumberAndMonthFormats() {
        Lang.shared.code = "de"
        XCTAssertEqual(Fmt.eur(1_234_567.4), "1.234.567 €")
        XCTAssertEqual(Fmt.pct(37.24), "37,2 %")
        XCTAssertEqual(monthLabel(2), "Mär 2027")
        XCTAssertEqual(monthLabelShort(9), "Okt 27")
        Lang.shared.code = "en"
        XCTAssertEqual(Fmt.eur(1_234_567.4), "1,234,567 €")
        XCTAssertEqual(Fmt.pct(37.24), "37.2 %")
        XCTAssertEqual(monthLabel(2), "Mar 2027")
        XCTAssertEqual(monthLabelShort(9), "Oct 27")
        XCTAssertEqual(Fmt.signedEur(-1500), "− 1,500 €")
    }

    func testCalculationDoesNotDependOnLanguage() {
        Lang.shared.code = "de"
        let de = Calculator.compute(Inputs())
        Lang.shared.code = "en"
        let en = Calculator.compute(Inputs())
        XCTAssertEqual(de.netVoll, en.netVoll)
        XCTAssertEqual(de.erstattung, en.erstattung)
        XCTAssertEqual(de.netFf, en.netFf)
    }

    func testFeatureTextsFollowTheLanguage() {
        Lang.shared.code = "en"
        XCTAssertEqual(Feature.taxOptimization.title, "Tax optimization")
        Lang.shared.code = "de"
        XCTAssertEqual(Feature.taxOptimization.title, "Steuer-Optimierung")
    }
}
