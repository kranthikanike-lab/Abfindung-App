import SwiftUI
import Charts

// MARK: - Shared helpers

/// Small floating card shown while the user touches or drags on a chart.
struct ValueBubble: View {
    struct Row: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let color: Color
    }
    let title: String
    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(rows) { row in
                HStack(spacing: 5) {
                    Circle().fill(row.color).frame(width: 7, height: 7)
                    Text(row.label).font(.caption2)
                    Spacer(minLength: 6)
                    Text(row.value).font(.caption2.weight(.bold)).monospacedDigit()
                }
            }
        }
        .padding(8)
        .frame(minWidth: 120, maxWidth: 230)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
    }
}

struct ChartTouchHint: View {
    var body: some View {
        Text("Tippen oder ziehen, um Werte zu sehen")
            .font(.caption2).foregroundStyle(.secondary)
    }
}

struct LegendRow: View {
    let items: [(String, Color, String?)]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                HStack(spacing: 6) {
                    Circle().fill(it.1).frame(width: 9, height: 9)
                    Text(it.0).font(.caption)
                    Spacer()
                    if let v = it.2 { Text(v).font(.caption.weight(.semibold)).monospacedDigit() }
                }
            }
        }
    }
}

// MARK: - Donut charts

struct DonutChart: View {
    struct Slice: Identifiable {
        var id: String { name }
        let name: String
        let value: Double
        let color: Color
    }
    let slices: [Slice]
    @State private var selectedAngle: Double?

    private var total: Double { slices.reduce(0) { $0 + max(0, $1.value) } }

    private var selected: Slice? {
        guard let angle = selectedAngle else { return nil }
        var cumulative = 0.0
        for s in slices {
            cumulative += max(0, s.value)
            if angle <= cumulative { return s }
        }
        return nil
    }

    var body: some View {
        Chart(slices) { s in
            SectorMark(angle: .value("Betrag", max(0, s.value)), innerRadius: .ratio(0.6), angularInset: 1.5)
                .foregroundStyle(s.color)
                .opacity(selected == nil || selected?.id == s.id ? 1 : 0.35)
                .cornerRadius(4)
        }
        .chartAngleSelection(value: $selectedAngle)
        .chartLegend(.hidden)
        .chartBackground { proxy in
            GeometryReader { geo in
                if let frame = proxy.plotFrame {
                    let rect = geo[frame]
                    VStack(spacing: 2) {
                        Text(selected?.name ?? "Gesamt").font(.caption2).foregroundStyle(.secondary)
                        Text(Fmt.eur(selected?.value ?? total)).font(.subheadline.weight(.bold)).monospacedDigit()
                        if let s = selected, total > 0 {
                            Text(Fmt.pct(max(0, s.value) / total * 100)).font(.caption2).foregroundStyle(s.color)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .frame(width: rect.width * 0.55)
                    .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .frame(height: 190)
    }
}

struct AgChart: View {
    let r: Results
    var body: some View {
        let slices = [DonutChart.Slice(name: "Sofort-Netto", value: r.netVoll, color: Theme.accent),
                      DonutChart.Slice(name: "Lohnsteuer-Einbehalt", value: r.einbehalten, color: Theme.danger)]
        VStack(spacing: 8) {
            DonutChart(slices: slices)
            LegendRow(items: [("Sofort-Netto", Theme.accent, Fmt.eur(r.netVoll)),
                              ("Lohnsteuer-Einbehalt", Theme.danger, Fmt.eur(r.einbehalten))])
            ChartTouchHint()
        }
    }
}

struct FaChart: View {
    let r: Results
    var body: some View {
        let slices = [DonutChart.Slice(name: "Optimal-Netto", value: r.netFf, color: Theme.success),
                      DonutChart.Slice(name: "Endgültige Steuer", value: r.finalAbfTax, color: Theme.warning)]
        VStack(spacing: 8) {
            DonutChart(slices: slices)
            LegendRow(items: [("Optimal-Netto", Theme.success, Fmt.eur(r.netFf)),
                              ("Endgültige Steuer", Theme.warning, Fmt.eur(r.finalAbfTax))])
            ChartTouchHint()
        }
    }
}

// MARK: - Bar charts

struct ErstattungChart: View {
    let r: Results
    @State private var selectedName: String?

    private struct Bar { let name: String; let value: Double; let color: Color }

    private var shown: [Bar] {
        let all = [
            Bar(name: "Fünftel-Basis", value: r.baseFuenftelRefund, color: Theme.accent),
            Bar(name: "DRV (50% Fünftel)", value: r.drvFuenftelRefund2028, color: Theme.cyan),
            Bar(name: "Rürup", value: r.ruerupSaving.savings, color: Theme.success),
            Bar(name: "PV-IAB", value: r.iabSaving.savings, color: Theme.purple)
        ]
        return all.filter { $0.value != 0 || $0.name == "Fünftel-Basis" }
    }

    var body: some View {
        let bars = shown
        VStack(spacing: 8) {
            Chart {
                ForEach(bars, id: \.name) { b in
                    BarMark(x: .value("Quelle", b.name), y: .value("€", b.value))
                        .foregroundStyle(b.color)
                        .opacity(selectedName == nil || selectedName == b.name ? 1 : 0.4)
                        .cornerRadius(6)
                }
                if let sel = selectedName, let b = bars.first(where: { $0.name == sel }) {
                    RuleMark(x: .value("Quelle", sel))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ValueBubble(title: "FA-Erstattung Okt. 2028",
                                        rows: [.init(label: b.name, value: Fmt.signedEur(b.value), color: b.color)])
                        }
                }
            }
            .chartXSelection(value: $selectedName)
            .chartLegend(.hidden)
            .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 9)) } }
            .frame(height: 200)
            ChartTouchHint()
        }
    }
}

struct SprinterWaterfall: View {
    let r: Results
    @State private var selectedName: String?

    private struct Bar: Identifiable {
        var id: String { name }
        let name: String
        let lo: Double
        let hi: Double
        let signed: Double
        let color: Color
    }

    private var bars: [Bar] {
        var run = 0.0
        var out: [Bar] = []
        out.append(Bar(name: "+ Netto-Prämie", lo: 0, hi: r.isolatedNettoPraemie,
                       signed: r.isolatedNettoPraemie, color: Theme.accent))
        run += r.isolatedNettoPraemie
        out.append(Bar(name: "+ Fünftel-Steuer", lo: run, hi: run + r.pureFuenftelAdvantage,
                       signed: r.pureFuenftelAdvantage, color: Theme.success))
        run += r.pureFuenftelAdvantage
        out.append(Bar(name: "− Netto-Gehalt", lo: run - r.lostNetSalary, hi: run,
                       signed: -r.lostNetSalary, color: Theme.danger))
        run -= r.lostNetSalary
        out.append(Bar(name: "− GKV/PV Lücke", lo: run - r.gkvTurboSim, hi: run,
                       signed: -r.gkvTurboSim, color: Theme.orange))
        run -= r.gkvTurboSim
        let rvAlg = r.rvSim + r.alg1Sim
        out.append(Bar(name: "− RV & ALG-1", lo: run - rvAlg, hi: run, signed: -rvAlg, color: Theme.yellow))
        let d = r.sprinterNetDiff
        out.append(Bar(name: "= ECHTER VORTEIL", lo: min(0, d), hi: max(0, d), signed: d,
                       color: d >= 0 ? Theme.success : Theme.danger))
        return out
    }

    var body: some View {
        let data = bars
        VStack(spacing: 8) {
            Chart {
                ForEach(data) { b in
                    BarMark(xStart: .value("von", b.lo), xEnd: .value("bis", b.hi), y: .value("Posten", b.name))
                        .foregroundStyle(b.color)
                        .opacity(selectedName == nil || selectedName == b.name ? 1 : 0.4)
                        .cornerRadius(4)
                }
                if let sel = selectedName, let b = data.first(where: { $0.name == sel }) {
                    RuleMark(y: .value("Posten", sel))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                        .annotation(position: .trailing, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ValueBubble(title: "Sprinter-Bilanz",
                                        rows: [.init(label: b.name, value: Fmt.signedEur(b.signed), color: b.color)])
                        }
                }
            }
            .chartYSelection(value: $selectedName)
            .chartYScale(domain: data.map { $0.name })
            .chartYAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 10)) } }
            .frame(height: 240)
            ChartTouchHint()
        }
    }
}

struct SprinterDetails: View {
    let r: Results
    @State private var open = false
    var body: some View {
        DisclosureGroup("📊 Sprinter-Bilanz & Wasserfall", isExpanded: $open) {
            VStack(spacing: 8) {
                TableRow(label: "+ Gewinne (Prämie & Steuer)", value: "+ " + Fmt.eur(r.sprinterGains), color: Theme.success)
                TableRow(label: "− Kosten (Gehalt, GKV, RV/ALG)", value: "− " + Fmt.eur(r.sprinterLosses), color: Theme.danger)
                TableRow(label: "= Echter Sprinter-Vorteil", value: Fmt.signedEur(r.sprinterNetDiff),
                         color: r.sprinterNetDiff >= 0 ? Theme.success : Theme.danger, bold: true)
                SprinterWaterfall(r: r)
            }.padding(.top, 8)
        }
        .font(.subheadline.weight(.semibold))
    }
}

// MARK: - Month line chart (used by the Gehalts-Switch)

struct LineSeries: Identifiable {
    let id = UUID()
    let name: String
    let values: [Double]
    let color: Color
}

struct MonthLineChart: View {
    let series: [LineSeries]
    var zeroLine = false
    var height: CGFloat = 230
    @State private var selectedX: Int?

    private var maxIndex: Int { max(0, (series.map { $0.values.count }.max() ?? 1) - 1) }

    private var selectedIndex: Int? {
        guard let x = selectedX else { return nil }
        return min(max(0, x), maxIndex)
    }

    var body: some View {
        VStack(spacing: 8) {
            Chart {
                ForEach(series) { s in
                    ForEach(Array(s.values.enumerated()), id: \.offset) { idx, v in
                        LineMark(x: .value("Monat", idx), y: .value("€", v), series: .value("Reihe", s.name))
                            .foregroundStyle(by: .value("Reihe", s.name))
                            .interpolationMethod(.monotone)
                    }
                }
                if zeroLine {
                    RuleMark(y: .value("0", 0)).foregroundStyle(Theme.danger)
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                }
                if let idx = selectedIndex {
                    RuleMark(x: .value("Monat", idx))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ValueBubble(title: monthLabel(idx),
                                        rows: series.map { s in
                                            .init(label: s.name,
                                                  value: idx < s.values.count ? Fmt.signedEur(s.values[idx]) : "–",
                                                  color: s.color)
                                        })
                        }
                }
            }
            .chartXSelection(value: $selectedX)
            .chartForegroundStyleScale(domain: series.map(\.name), range: series.map(\.color))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { v in
                    AxisGridLine()
                    AxisValueLabel {
                        if let i = v.as(Int.self) { Text(monthLabel(i)).font(.system(size: 9)) }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = v.as(Double.self) { Text(Fmt.eur(d)).font(.system(size: 9)) }
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: height)
            ChartTouchHint()
        }
    }
}

// MARK: - Reichweite

/// Life-phase timeline (Gehalt, Ruhenszeit, ALG 1, Privatiers) with touch details.
struct PhaseChart: View {
    let std: RunwayResult
    let spr: RunwayResult
    @State private var selectedScenario: String?

    private struct Seg: Identifiable {
        var id: String { scenario + phase }
        let scenario: String
        let phase: String
        let months: Int
    }

    private let phases = ["1. Gehaltsphase", "2. Ruhenszeit (GKV)", "3. ALG-1 Bezug", "4. Privatiers-Phase"]
    private let colors = [Theme.indigo, Theme.warning, Theme.cyan, Theme.success]

    private func segs(_ name: String, _ r: RunwayResult) -> [Seg] {
        [Seg(scenario: name, phase: phases[0], months: r.salMonthsTotal),
         Seg(scenario: name, phase: phases[1], months: r.dynamicRuhens),
         Seg(scenario: name, phase: phases[2], months: r.algMonths),
         Seg(scenario: name, phase: phases[3], months: r.postPhaseMonths)]
    }

    var body: some View {
        let all = segs("Standard (Frist)", std) + segs("Sprinter (Sofort)", spr)
        VStack(spacing: 8) {
            Chart {
                ForEach(all) { s in
                    BarMark(x: .value("Monate", s.months), y: .value("Szenario", s.scenario))
                        .foregroundStyle(by: .value("Phase", s.phase))
                        .opacity(selectedScenario == nil || selectedScenario == s.scenario ? 1 : 0.4)
                }
                if let sel = selectedScenario {
                    let rows = all.filter { $0.scenario == sel }
                    RuleMark(y: .value("Szenario", sel))
                        .foregroundStyle(Color.clear)
                        .annotation(position: .overlay, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            ValueBubble(title: sel,
                                        rows: rows.enumerated().map { idx, s in
                                            .init(label: s.phase, value: "\(s.months) Mon.", color: colors[idx])
                                        })
                        }
                }
            }
            .chartYSelection(value: $selectedScenario)
            .chartForegroundStyleScale(domain: phases, range: colors)
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 190)
            ChartTouchHint()
        }
    }
}

/// Account balance over time: green above zero, red below, with markers for the key events and the
/// month the money runs out. One scenario is shown prominently, the other as a faint dashed line.
struct RunwayBalanceChart: View {
    let std: RunwayResult
    let spr: RunwayResult
    @State private var showSprinter = true
    @State private var selectedX: Int?

    private struct Event: Identifiable {
        var id: String { name }
        let month: Int
        let name: String
        let color: Color
    }

    private var main: RunwayResult { showSprinter ? spr : std }
    private var other: RunwayResult { showSprinter ? std : spr }
    private var mainName: String { showSprinter ? "Sprinter" : "Standard" }
    private var otherName: String { showSprinter ? "Standard" : "Sprinter" }

    private var events: [Event] {
        let r = main
        let last = max(0, r.curve.count - 1)
        var list: [Event] = [
            Event(month: min(r.salMonthsTotal, 11), name: "Auszahlung", color: Theme.accent),
            Event(month: 21, name: "FA Okt. 2028", color: Theme.purple),
            Event(month: r.salMonthsTotal + r.dynamicRuhens + r.algMonths, name: "ALG 1 endet", color: Theme.cyan)
        ]
        if r.exhaustedMonth < 240 {
            list.append(Event(month: last, name: "Geld aufgebraucht", color: Theme.danger))
        }
        return list.filter { $0.month <= last }
    }

    private var selectedIndex: Int? {
        guard let x = selectedX else { return nil }
        return min(max(0, x), max(0, main.curve.count - 1))
    }

    var body: some View {
        let r = main
        let evs = events
        VStack(alignment: .leading, spacing: 10) {
            Picker("Szenario", selection: $showSprinter) {
                Text("Sprinter").tag(true)
                Text("Standard").tag(false)
            }
            .pickerStyle(.segmented)

            Chart {
                ForEach(Array(r.curve.enumerated()), id: \.offset) { idx, v in
                    AreaMark(x: .value("Monat", idx), yStart: .value("Null", 0), yEnd: .value("Plus", max(v, 0)),
                             series: .value("Bereich", "plus"), stacking: .unstacked)
                        .foregroundStyle(Theme.success.opacity(0.28))
                    AreaMark(x: .value("Monat", idx), yStart: .value("Null", 0), yEnd: .value("Minus", min(v, 0)),
                             series: .value("Bereich", "minus"), stacking: .unstacked)
                        .foregroundStyle(Theme.danger.opacity(0.35))
                }
                ForEach(Array(other.curve.enumerated()), id: \.offset) { idx, v in
                    LineMark(x: .value("Monat", idx), y: .value("Saldo", v), series: .value("Linie", otherName))
                        .foregroundStyle(Color.secondary.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                }
                ForEach(Array(r.curve.enumerated()), id: \.offset) { idx, v in
                    LineMark(x: .value("Monat", idx), y: .value("Saldo", v), series: .value("Linie", mainName))
                        .foregroundStyle(Color.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                RuleMark(y: .value("Null", 0)).foregroundStyle(Color.primary.opacity(0.6))
                ForEach(evs) { e in
                    RuleMark(x: .value("Ereignis", e.month))
                        .foregroundStyle(e.color.opacity(0.75))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                }
                if let idx = selectedIndex {
                    RuleMark(x: .value("Monat", idx))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ValueBubble(title: monthLabel(idx),
                                        rows: [
                                            .init(label: mainName, value: Fmt.signedEur(r.curve[idx]), color: Color.primary),
                                            .init(label: otherName,
                                                  value: idx < other.curve.count ? Fmt.signedEur(other.curve[idx]) : "–",
                                                  color: Color.secondary)
                                        ])
                        }
                }
            }
            .chartXSelection(value: $selectedX)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { v in
                    AxisGridLine()
                    AxisValueLabel {
                        if let i = v.as(Int.self) { Text(monthLabel(i)).font(.system(size: 9)) }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = v.as(Double.self) { Text(Fmt.eur(d)).font(.system(size: 9)) }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 250)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(evs) { e in
                    HStack(spacing: 6) {
                        Rectangle().fill(e.color).frame(width: 14, height: 3)
                        Text(e.name).font(.caption)
                        Spacer()
                        Text(monthLabel(e.month)).font(.caption.weight(.semibold)).monospacedDigit()
                    }
                }
                HStack(spacing: 6) {
                    Rectangle().fill(Color.secondary.opacity(0.6)).frame(width: 14, height: 3)
                    Text("\(otherName) (zum Vergleich)").font(.caption)
                    Spacer()
                }
                if r.exhaustedMonth >= 240 {
                    Text("Das Geld reicht in dieser Simulation über 20 Jahre.").font(.caption).foregroundStyle(Theme.success)
                }
            }
            ChartTouchHint()
        }
    }
}
