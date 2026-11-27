import SwiftUI
import Observation

enum AppTab: Hashable, CaseIterable { case inputs, optimization, results, runway, crossover }

@Observable
final class AppModel {
    private static let storeKey = "abfindungs_optimizer_inputs_v1"
    private static let proKey = "abfindungs_optimizer_pro_v1"

    var inputs: Inputs {
        didSet {
            guard inputs != oldValue else { return }
            recompute()
            persist()
        }
    }

    /// Pro tier unlocked (test switch for now; in-app purchase later).
    var isPro: Bool {
        didSet {
            guard isPro != oldValue else { return }
            UserDefaults.standard.set(isPro, forKey: Self.proKey)
            recompute()
        }
    }

    private(set) var results: Results
    var selectedTab: AppTab = .inputs

    init(inputs: Inputs? = nil, isPro: Bool? = nil) {
        let initial = inputs ?? Self.load() ?? Inputs()
        let pro = isPro ?? UserDefaults.standard.bool(forKey: Self.proKey)
        self.inputs = initial
        self.isPro = pro
        self.results = Calculator.compute(initial, pro: pro)
        clampRuerup()
    }

    private func recompute() {
        results = Calculator.compute(inputs, pro: isPro)
        clampRuerup()
    }

    /// The Rürup slider is capped dynamically (like the HTML slider.max).
    private func clampRuerup() {
        let cap = jsRound(results.maxRuerup)
        if inputs.ruerup > cap {
            inputs.ruerup = cap
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(inputs) {
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        }
    }

    private static func load() -> Inputs? {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else { return nil }
        return try? JSONDecoder().decode(Inputs.self, from: data)
    }

    // MARK: Pro gate

    /// Returns true if the feature may be used; otherwise opens the unlock sheet.
    @discardableResult
    func requirePro() -> Bool {
        if isPro { return true }
        AppSheets.shared.showUnlock = true
        return false
    }

    // MARK: Actions

    func setOptEnabled(_ on: Bool) {
        guard !on || requirePro() else { return }
        inputs.optEnabled = on
        if !on { inputs.bav = 0; inputs.drv = 0; inputs.ruerup = 0; inputs.iabInvest = 0 }
    }

    func setKinder(_ k: Double) {
        inputs.kinder = k
        inputs.alg1Satz = k > 0 ? 0.67 : 0.60
    }

    /// Sliders snap to their step (like the HTML range inputs did).
    private static func snap(_ v: Double, step: Double, max cap: Double) -> Double {
        min(cap, (v / step).rounded() * step)
    }

    func applyRuerupSweetSpot() {
        guard requirePro() else { return }
        inputs.optEnabled = true
        inputs.ruerup = Self.snap(results.ruerupSweetSpot, step: 250, max: jsRound(results.maxRuerup))
    }

    func applyIabSweetSpot() {
        guard requirePro() else { return }
        inputs.optEnabled = true
        inputs.iabInvest = Self.snap(results.iabSweetInvest, step: 2000, max: 400_000)
    }

    func applyDrvDeficit(cost: Double) {
        guard requirePro() else { return }
        inputs.optEnabled = true
        inputs.drvMax = max(60_000, cost)
        inputs.drv = cost
    }

    func apply(_ preset: Preset) {
        if preset == .reset {
            inputs = Inputs()
            selectedTab = .inputs
            return
        }
        // All quick scenarios use Pro features.
        guard requirePro() else { return }
        inputs.iabInvest = 0
        inputs.neuesGehalt = 0
        switch preset {
        case .sprinterSweet:
            inputs.isTurbo = true
            inputs.optEnabled = true
            inputs.bav = 42_480
            let probe = Calculator.compute(inputs)
            inputs.ruerup = Self.snap(probe.ruerupSweetSpot, step: 250, max: jsRound(probe.maxRuerup))
            selectedTab = .optimization
        case .runwayCheck:
            inputs.isTurbo = true
            setOptEnabled(false)
            inputs.runwayEnabled = true
            selectedTab = .runway
        case .gehaltsSwitch:
            inputs.isTurbo = true
            inputs.crossoverEnabled = true
            selectedTab = .crossover
        case .reset: break
        }
    }
}
