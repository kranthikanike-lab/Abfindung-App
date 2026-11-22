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
                    Text(row.label).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 6)
                    Text(row.value).font(.caption2.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .padding(8)
        .frame(minWidth: 120, maxWidth: 270)
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

    private func bubble(at idx: Int) -> ValueBubble {
        var rows: [ValueBubble.Row] = []
        for s in series {
            let text: String = idx < s.values.count ? Fmt.signedEur(s.values[idx]) : "–"
            rows.append(ValueBubble.Row(label: s.name, value: text, color: s.color))
        }
        return ValueBubble(title: monthLabel(idx), rows: rows)
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
                            bubble(at: idx)
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

/// Life-phase timeline in calendar months. It starts at the month chosen in the inputs
/// ("Start Frist / Sprinter-Austritt"), so Standard works through the notice period while Sprinter leaves right away.
struct PhaseChart: View {
    let std: RunwayResult
    let spr: RunwayResult
    /// Months since Jan 2027 where the timeline starts (= chosen start month).
    let startIndex: Int
    @State private var selectedScenario: String?

    private struct Seg: Identifiable {
        var id: String { scenario + phase }
        let scenario: String
        let phase: String
        let from: Int
        let to: Int
        var months: Int { to - from }
    }

    private let phases = ["1. Gehaltsphase", "2. Ruhenszeit (GKV)", "3. ALG-1 Bezug", "4. Privatiers-Phase"]
    private let colors: [Color] = [Theme.indigo, Theme.warning, Theme.cyan, Theme.success]

    private func segs(_ name: String, _ r: RunwayResult) -> [Seg] {
        let lengths: [Int] = [max(0, r.salMonthsTotal - startIndex), r.dynamicRuhens, r.algMonths, r.postPhaseMonths]
        var out: [Seg] = []
        var cursor = startIndex
        for (i, len) in lengths.enumerated() {
            out.append(Seg(scenario: name, phase: phases[i], from: cursor, to: cursor + len))
            cursor += len
        }
        return out
    }

    private func bubble(for scenario: String, in all: [Seg]) -> ValueBubble {
        var rows: [ValueBubble.Row] = []
        let mine: [Seg] = all.filter { $0.scenario == scenario }
        for (idx, seg) in mine.enumerated() {
            let text: String = seg.months > 0
                ? "\(monthLabel(seg.from)) – \(monthLabel(seg.to - 1)) · \(seg.months) Mon."
                : "–"
            rows.append(ValueBubble.Row(label: seg.phase, value: text, color: colors[idx]))
        }
        return ValueBubble(title: scenario, rows: rows)
    }

    var body: some View {
        let all: [Seg] = segs("Standard (Frist)", std) + segs("Sprinter (Sofort)", spr)
        let drawn: [Seg] = all.filter { $0.months > 0 }
        let endIndex: Int = max(startIndex + 1, all.map { $0.to }.max() ?? startIndex + 1)
        VStack(spacing: 8) {
            Chart {
                ForEach(drawn) { s in
                    BarMark(xStart: .value("Von", s.from), xEnd: .value("Bis", s.to), y: .value("Szenario", s.scenario))
                        .foregroundStyle(by: .value("Phase", s.phase))
                        .opacity(selectedScenario == nil || selectedScenario == s.scenario ? 1 : 0.4)
                }
                if let sel = selectedScenario {
                    RuleMark(y: .value("Szenario", sel))
                        .foregroundStyle(Color.clear)
                        .annotation(position: .overlay, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            bubble(for: sel, in: all)
                        }
                }
            }
            .chartYSelection(value: $selectedScenario)
            .chartXScale(domain: startIndex...endIndex)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { v in
                    AxisGridLine()
                    AxisValueLabel {
                        if let i = v.as(Int.self) { Text(monthLabel(i)).font(.system(size: 9)) }
                    }
                }
            }
            .chartForegroundStyleScale(domain: phases, range: colors)
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 190)
            ChartTouchHint()
        }
    }
}

/// Account balance over time for both scenarios in their own colors (same colors as the KPI tiles):
/// Sprinter green, Standard blue. The area below zero is shaded light red. A shared marker shows the
/// Finanzamt refund in Oct. 2028, and a dot marks the month the money runs out in each scenario.
struct RunwayBalanceChart: View {
    let std: RunwayResult
    let spr: RunwayResult
    @State private var selectedX: Int?

    private let sprName = "Sprinter"
    private let stdName = "Standard"
    private let faMonth = 21   // Oct 2028

    private var maxIndex: Int { max(0, max(std.curve.count, spr.curve.count) - 1) }

    private var minValue: Double {
        min(0, min(std.curve.min() ?? 0, spr.curve.min() ?? 0))
    }

    private var selectedIndex: Int? {
        guard let x = selectedX else { return nil }
        return min(max(0, x), maxIndex)
    }

    private func bubble(at idx: Int) -> ValueBubble {
        let sprText: String = idx < spr.curve.count ? Fmt.signedEur(spr.curve[idx]) : "–"
        let stdText: String = idx < std.curve.count ? Fmt.signedEur(std.curve[idx]) : "–"
        let rows: [ValueBubble.Row] = [
            ValueBubble.Row(label: sprName, value: sprText, color: Theme.success),
            ValueBubble.Row(label: stdName, value: stdText, color: Theme.accent)
        ]
        return ValueBubble(title: monthLabel(idx), rows: rows)
    }

    @ChartContentBuilder
    private var dangerZone: some ChartContent {
        if minValue < 0 {
            RectangleMark(xStart: .value("Start", 0), xEnd: .value("Ende", maxIndex),
                          yStart: .value("Minimum", minValue), yEnd: .value("Null", 0))
                .foregroundStyle(Theme.danger.opacity(0.08))
        }
    }

    @ChartContentBuilder
    private func line(_ curve: [Double], name: String) -> some ChartContent {
        ForEach(Array(curve.enumerated()), id: \.offset) { idx, v in
            LineMark(x: .value("Monat", idx), y: .value("Saldo", v), series: .value("Reihe", name))
                .foregroundStyle(by: .value("Szenario", name))
                .lineStyle(StrokeStyle(lineWidth: 2.2))
        }
    }

    @ChartContentBuilder
    private func endDot(_ r: RunwayResult, color: Color) -> some ChartContent {
        if r.exhaustedMonth < 240, let last = r.curve.last {
            PointMark(x: .value("Monat", r.curve.count - 1), y: .value("Saldo", last))
                .symbolSize(70)
                .foregroundStyle(color)
        }
    }

    @ChartContentBuilder
    private var selectionMark: some ChartContent {
        if let idx = selectedIndex {
            RuleMark(x: .value("Monat", idx))
                .foregroundStyle(Color.secondary.opacity(0.5))
                .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                    bubble(at: idx)
                }
        }
    }

    private var chart: some View {
        Chart {
            dangerZone
            RuleMark(y: .value("Null", 0)).foregroundStyle(Color.primary.opacity(0.55))
            if faMonth <= maxIndex {
                RuleMark(x: .value("FA", faMonth))
                    .foregroundStyle(Theme.purple.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            }
            line(std.curve, name: stdName)
            line(spr.curve, name: sprName)
            endDot(std, color: Theme.accent)
            endDot(spr, color: Theme.success)
            selectionMark
        }
        .chartXSelection(value: $selectedX)
        .chartForegroundStyleScale(domain: [sprName, stdName], range: [Theme.success, Theme.accent])
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
        .frame(height: 250)
    }

    private func endText(_ r: RunwayResult) -> String {
        r.exhaustedMonth < 240 ? monthLabel(r.curve.count - 1) : "> 20 Jahre"
    }

    private var datesTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                Text("").gridColumnAlignment(.leading)
                Text(sprName).font(.caption.weight(.bold)).foregroundStyle(Theme.success)
                Text(stdName).font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
            }
            GridRow {
                Text("Auszahlung").font(.caption)
                Text(monthLabel(min(spr.salMonthsTotal, 11))).font(.caption).monospacedDigit()
                Text(monthLabel(min(std.salMonthsTotal, 11))).font(.caption).monospacedDigit()
            }
            GridRow {
                Text("ALG 1 endet").font(.caption)
                Text(monthLabel(spr.salMonthsTotal + spr.dynamicRuhens + spr.algMonths)).font(.caption).monospacedDigit()
                Text(monthLabel(std.salMonthsTotal + std.dynamicRuhens + std.algMonths)).font(.caption).monospacedDigit()
            }
            GridRow {
                Text("Geld aufgebraucht").font(.caption)
                Text(endText(spr)).font(.caption.weight(.semibold)).monospacedDigit()
                Text(endText(std)).font(.caption.weight(.semibold)).monospacedDigit()
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            chart
            HStack(spacing: 6) {
                Rectangle().fill(Theme.purple).frame(width: 14, height: 3)
                Text("Finanzamt-Erstattung \(monthLabel(faMonth))").font(.caption)
                Spacer()
                Rectangle().fill(Theme.danger.opacity(0.25)).frame(width: 14, height: 8)
                Text("Defizit").font(.caption)
            }
            datesTable
            ChartTouchHint()
        }
    }
}
