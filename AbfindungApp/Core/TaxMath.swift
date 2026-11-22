import Foundation

/// 2027 constants.
/// Income-tax values follow the Regierungsentwurf "Einkommensteuerreformgesetz 2027" (BT-Drucksache 21/8235)
/// and may change until the law is passed. Social-insurance values follow the Sozialversicherungs-Rechengrößen 2027.
enum Const {
    static let bbgRV = 106_200.0
    static let bbgRVMonat = 8_850.0
    static let bbgKV = 76_500.0
    static let bbgKVMonat = 6_375.0
    static let maxBav = 50_976.0
    static let maxAltersvorsorge = 32_308.0
    static let anPauschbetrag = 1_430.0
    static let gkvMindestBemessung = 1_376.67
    /// Kinderfreibetrag incl. Betreuungsfreibetrag, both parents: 2 × (3.564 + 1.464).
    static let kinderFreibetrag = 10_056.0
    /// Kindergeld 267 €/month.
    static let kindergeld = 3_204.0
    /// Solidaritätszuschlag Freigrenze (single); doubled for splitting. Not changed by the draft.
    static let soliFreigrenze = 20_350.0

    // Pflegeversicherung (3,6 % total). Where sources conflict, the more cautious (higher) value is used.
    static let pvEmployeeShare = 0.018          // half of 3,6 %
    static let pvChildlessSurcharge = 0.009     // planned 2027 (sources: 0,7 or 0,9) -> cautious: 0,9
    static let pvTotal = 0.036
}

/// JavaScript `Math.round` semantics (half rounds toward +infinity).
@inline(__always) func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

struct TaxResult {
    var est: Double
    var soli: Double
    var kist: Double
    var total: Double
    var kfbWon: Bool
}

/// Tax withheld by the employer (Lohnsteuer + Soli + Kirchensteuer).
struct Withholding {
    var lst: Double
    var soli: Double
    var kist: Double
    var total: Double { lst + soli + kist }
}

/// Parameters shared by all tax calls of one calculation.
struct TaxCtx {
    var spl: Double
    var kinder: Double
    /// Kirchensteuersatz as a fraction (0, 0.08, 0.09).
    var kist: Double

    /// Annual assessment (Veranlagung): Fünftelregelung, Günstigerprüfung, Progressionsvorbehalt.
    func annual(_ zve: Double, fuenftel: Bool, abf: Double, prog: Double = 0) -> TaxResult {
        TaxMath.totalTax(zve: zve, spl: spl, fuenftel: fuenftel, abf: abf, kinder: kinder, prog: prog, kist: kist)
    }

    /// Payroll withholding: the Lohnsteuer itself ignores the Kinderfreibetrag (Kindergeld is paid separately);
    /// only Soli and Kirchensteuer are computed on the tax reduced by the Kinderfreibeträge (ELStAM).
    func withholding(_ zve: Double) -> Withholding {
        let estNo = TaxMath.est(zve, spl)
        let estK = TaxMath.est(zve - kinder * Const.kinderFreibetrag, spl)
        return Withholding(lst: estNo, soli: TaxMath.soli(estK, spl), kist: kist * estK)
    }
}

enum TaxMath {
    /// Einkommensteuer-Tarif 2027 (§ 32a Abs. 1 EStG, Regierungsentwurf). `spl` = 1 (Grund) or 2 (Splitting).
    static func est(_ zve: Double, _ spl: Double) -> Double {
        if zve <= 0 { return 0 }
        let x = (zve / spl).rounded(.down)
        var e: Double
        if x <= 12_564 {
            e = 0
        } else if x <= 17_799 {
            let y = (x - 12_564) / 10_000
            e = (952.24 * y + 1_400) * y
        } else if x <= 70_600 {
            let z = (x - 17_799) / 10_000
            e = (170.74 * z + 2_397) * z + 993.86
        } else if x <= 249_999 {
            e = 0.42 * x - 11_241.73
        } else if x <= 279_999 {
            e = 0.45 * x - 18_741.70
        } else {
            e = 0.47 * x - 24_341.68
        }
        return e.rounded(.down) * spl
    }

    static func soli(_ est: Double, _ spl: Double) -> Double {
        if est <= 0 { return 0 }
        let fg = Const.soliFreigrenze * spl
        if est <= fg { return 0 }
        return min((est - fg) * 0.119, est * 0.055)
    }

    /// Tax incl. Fünftelregelung, Kinderfreibetrag/Kindergeld Günstigerprüfung, Progressionsvorbehalt and Kirchensteuer.
    /// Soli and Kirchensteuer are always based on the tax reduced by the Kinderfreibeträge (§ 51a EStG, § 3 SolZG).
    static func totalTax(zve rawZve: Double, spl: Double, fuenftel: Bool, abf: Double,
                         kinder: Double = 0, prog: Double = 0, kist: Double = 0) -> TaxResult {
        let kfbTotal = kinder * Const.kinderFreibetrag
        let kgTotal = kinder * Const.kindergeld

        func calc(_ baseIn: Double) -> Double {
            var base = baseIn
            var a = abf
            // § 34 Abs. 1 Satz 3 EStG: a negative remaining income is offset against the Abfindung first.
            if fuenftel && a > 0 && base < 0 {
                a = max(0, a + base)
                base = 0
            }
            if a <= 0 && prog <= 0 { return est(base, spl) }
            let fifthAbf = fuenftel ? a / 5 : a
            let mult: Double = fuenftel ? 5 : 1
            if prog <= 0 {
                let tBase = est(base, spl)
                let tFull = est(base + fifthAbf, spl)
                return tBase + mult * max(0, tFull - tBase)
            } else {
                let ref = base + fifthAbf + prog
                let rate = ref > 0 ? est(ref, spl) / ref : 0
                let tBaseProg = jsRound(max(0, base) * rate)
                let tFullProg = jsRound(max(0, base + fifthAbf) * rate)
                return tBaseProg + mult * max(0, tFullProg - tBaseProg)
            }
        }

        let estNoKfb = calc(rawZve)
        let estWithKfb = calc(rawZve - kfbTotal)
        let soliAmount = soli(estWithKfb, spl)
        let kistAmount = kist * estWithKfb
        if kinder > 0 && (estNoKfb - estWithKfb) > kgTotal {
            return TaxResult(est: estWithKfb, soli: soliAmount, kist: kistAmount,
                             total: estWithKfb + soliAmount + kistAmount, kfbWon: true)
        }
        return TaxResult(est: estNoKfb, soli: soliAmount, kist: kistAmount,
                         total: estNoKfb + soliAmount + kistAmount, kfbWon: false)
    }

    /// Employee share of the Pflegeversicherung (1,8 %; minus 0,25 points per additional child from the 2nd to the 5th;
    /// childless members pay the surcharge on top).
    static func pvRate(_ kinder: Double) -> Double {
        if kinder > 0 {
            return Const.pvEmployeeShare - min(4, max(0, kinder.rounded(.up) - 1)) * 0.0025
        }
        return Const.pvEmployeeShare + Const.pvChildlessSurcharge
    }

    /// Full Pflegeversicherung rate for self-paying members (3,6 %, childless + surcharge).
    static func pvRateSelfPaid(_ kinder: Double) -> Double {
        kinder > 0 ? Const.pvTotal : Const.pvTotal + Const.pvChildlessSurcharge
    }

    static func employmentZve(_ gross: Double, zb: Double, kinder: Double) -> Double {
        if gross <= 0 { return 0 }
        let pausch = min(gross, Const.anPauschbetrag)
        let rvBasis = min(gross, Const.bbgRV)
        let kvBasis = min(gross, Const.bbgKV)
        let vorsorge = rvBasis * 0.093 + kvBasis * (0.073 + zb / 200 + pvRate(kinder))
        return max(0, gross - pausch - vorsorge)
    }

    static func sozAbzug(_ gross: Double, zb: Double, kinder: Double) -> Double {
        if gross <= 0 { return 0 }
        let rvAlv = min(gross, Const.bbgRV)
        let kv = min(gross, Const.bbgKV)
        return rvAlv * (0.093 + 0.013) + kv * (0.073 + zb / 200 + pvRate(kinder))
    }

    static func gkvHoechstsatzMonat(_ zb: Double, kinder: Double) -> Double {
        Const.bbgKVMonat * (0.146 + zb / 100 + pvRateSelfPaid(kinder))
    }

    static func gkvMindestMonat(_ zb: Double, kinder: Double) -> Double {
        Const.gkvMindestBemessung * (0.146 + zb / 100 + pvRateSelfPaid(kinder))
    }

    static func autoAlg1(monthlyGross: Double, satz: Double) -> Double {
        let bemessung = min(monthlyGross, Const.bbgRVMonat)
        let pauschalSv = bemessung * 0.20
        let lstMonat = est(max(0, (bemessung - pauschalSv) * 12 - Const.anPauschbetrag), 1) / 12
        let leistungsentgelt = max(0, bemessung - pauschalSv - lstMonat)
        return jsRound(leistungsentgelt * satz)
    }

    static func maxPartnerGrossForSplitting(userZve: Double, taxableAbf: Double, kinder: Double, zb: Double,
                                            kist: Double) -> Double {
        let split = TaxCtx(spl: 2, kinder: kinder, kist: kist)
        let single = TaxCtx(spl: 1, kinder: kinder, kist: kist)
        var low = 0.0, high = 250_000.0, best = 0.0
        for _ in 0..<28 {
            let mid = (low + high) / 2
            let pZve = employmentZve(mid, zb: zb, kinder: kinder)
            let tSplit = split.annual(userZve + pZve, fuenftel: true, abf: taxableAbf).total
            let tSingle = single.annual(userZve, fuenftel: true, abf: taxableAbf).total
                + single.annual(pZve, fuenftel: false, abf: 0).total
            if tSplit <= tSingle { best = mid; low = mid } else { high = mid }
        }
        return jsRound(best / 100) * 100
    }
}
