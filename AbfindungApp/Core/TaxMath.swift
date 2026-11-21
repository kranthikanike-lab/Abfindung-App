import Foundation

/// 2027 statutory constants (ported 1:1 from rechner_pro_v26_9.html).
enum Const {
    static let bbgRV = 106_200.0
    static let bbgRVMonat = 8_850.0
    static let bbgKV = 76_500.0
    static let bbgKVMonat = 6_375.0
    static let maxBav = 50_976.0
    static let maxAltersvorsorge = 32_308.0
    static let anPauschbetrag = 1_430.0
    static let gkvMindestBemessung = 1_376.67
    static let kinderFreibetrag = 10_056.0
    static let kindergeld = 3_204.0
}

/// JavaScript `Math.round` semantics (half rounds toward +infinity).
@inline(__always) func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

struct TaxResult {
    var est: Double
    var soli: Double
    var total: Double
    var kfbWon: Bool
}

enum TaxMath {
    /// Einkommensteuer-Tarif 2027 (§ 32a EStG). `spl` = 1 (Grund) or 2 (Splitting).
    static func est(_ zve: Double, _ spl: Double) -> Double {
        if zve <= 0 { return 0 }
        let x = (zve / spl).rounded(.down)
        var est: Double
        if x <= 12_564 {
            est = 0
        } else if x <= 18_000 {
            let y = (x - 12_564) / 10_000
            est = (919.8 * y + 1_400) * y
        } else if x <= 70_600 {
            let z = (x - 18_000) / 10_000
            est = (171.1 * z + 2_400) * z + 1_032.8
        } else if x <= 285_000 {
            est = 0.42 * x - 11_260
        } else {
            est = 0.45 * x - 19_810
        }
        return est.rounded(.down) * spl
    }

    static func soli(_ est: Double, _ spl: Double) -> Double {
        if est <= 0 { return 0 }
        let fg = 19_450 * spl
        if est <= fg { return 0 }
        return min((est - fg) * 0.119, est * 0.055)
    }

    /// Tax incl. Fünftelregelung, Kinderfreibetrag/Kindergeld Günstigerprüfung and Progressionsvorbehalt.
    static func totalTax(zve rawZve: Double, spl: Double, fuenftel: Bool, abf: Double,
                         kinder: Double = 0, prog: Double = 0) -> TaxResult {
        let kfbTotal = kinder * Const.kinderFreibetrag
        let kgTotal = kinder * Const.kindergeld

        func calc(_ baseZve: Double) -> Double {
            if abf <= 0 && prog <= 0 { return est(baseZve, spl) }
            let fifthAbf = fuenftel ? abf / 5 : abf
            let mult: Double = fuenftel ? 5 : 1
            if prog <= 0 {
                let tBase = est(baseZve, spl)
                let tFull = est(baseZve + fifthAbf, spl)
                return tBase + mult * max(0, tFull - tBase)
            } else {
                let ref = baseZve + fifthAbf + prog
                let rate = ref > 0 ? est(ref, spl) / ref : 0
                let tBaseProg = jsRound(max(0, baseZve) * rate)
                let tFullProg = jsRound(max(0, baseZve + fifthAbf) * rate)
                return tBaseProg + mult * max(0, tFullProg - tBaseProg)
            }
        }

        let estNoKfb = calc(rawZve)
        let estWithKfb = calc(rawZve - kfbTotal)
        let soliAmount = Self.soli(estWithKfb, spl)
        if kinder > 0 && (estNoKfb - estWithKfb) > kgTotal {
            return TaxResult(est: estWithKfb, soli: soliAmount, total: estWithKfb + soliAmount, kfbWon: true)
        }
        return TaxResult(est: estNoKfb, soli: soliAmount, total: estNoKfb + soliAmount, kfbWon: false)
    }

    static func pvRate(_ kinder: Double) -> Double {
        kinder > 0 ? 0.024 - min(4, max(0, kinder.rounded(.up) - 1)) * 0.0025 : 0.030
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

    static func gkvHoechstsatzMonat(_ zb: Double) -> Double {
        Const.bbgKVMonat * (0.146 + zb / 100 + 0.036)
    }

    static func gkvMindestMonat(_ zb: Double, kinder: Double) -> Double {
        let pv = kinder > 0 ? 0.036 : 0.042
        return Const.gkvMindestBemessung * (0.146 + zb / 100 + pv)
    }

    static func autoAlg1(monthlyGross: Double, satz: Double) -> Double {
        let bemessung = min(monthlyGross, Const.bbgRVMonat)
        let pauschalSv = bemessung * 0.20
        let lstMonat = est(max(0, (bemessung - pauschalSv) * 12 - Const.anPauschbetrag), 1) / 12
        let leistungsentgelt = max(0, bemessung - pauschalSv - lstMonat)
        return jsRound(leistungsentgelt * satz)
    }

    static func maxPartnerGrossForSplitting(userZve: Double, taxableAbf: Double, kinder: Double, zb: Double) -> Double {
        var low = 0.0, high = 250_000.0, best = 0.0
        for _ in 0..<28 {
            let mid = (low + high) / 2
            let pZve = employmentZve(mid, zb: zb, kinder: kinder)
            let tSplit = totalTax(zve: userZve + pZve, spl: 2, fuenftel: true, abf: taxableAbf, kinder: kinder).total
            let tSingle = totalTax(zve: userZve, spl: 1, fuenftel: true, abf: taxableAbf, kinder: kinder).total
                + totalTax(zve: pZve, spl: 1, fuenftel: false, abf: 0, kinder: kinder).total
            if tSplit <= tSingle { best = mid; low = mid } else { high = mid }
        }
        return jsRound(best / 100) * 100
    }
}
