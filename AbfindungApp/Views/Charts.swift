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

// MARK: - Comparison area chart (Reichweite balance and Gehalts-Switch)

/// Two series on a month axis, drawn as non-overlapping layers:
/// - blue: the shared base, from zero up to the lower of the two lines
/// - green band: between the lines where Sprinter is ahead
/// - orange band: between the lines where Standard is ahead
/// Thin edge lines show each scenario (Sprinter green, Standard blue). A series that has ended counts as 0.
struct ComparisonAreaChart: View {
    let spr: [Double]
    let std: [Double]
    var sprName = "Sprinter"
    var stdName = "Standard"
    var zeroColor: Color = Color.primary.opacity(0.55)
    var zeroDashed = false
    var zeroLabel: String? = nil
    var markerMonth: Int? = nil
    var markerLabel: String? = nil
    var markerColor: Color = Theme.purple
    var sprEndDot = false
    var stdEndDot = false
    var height: CGFloat = 250
    @State private var selectedX: Int?

    private var maxIndex: Int { max(0, max(std.count, spr.count) - 1) }

    private var selectedIndex: Int? {
        guard let x = selectedX else { return nil }
        return min(max(0, x), maxIndex)
    }

    private var indices: [Int] { Array(0...maxIndex) }

    private func sprValue(_ idx: Int) -> Double { idx < spr.count ? spr[idx] : 0 }
    private func stdValue(_ idx: Int) -> Double { idx < std.count ? std[idx] : 0 }
    private func low(_ idx: Int) -> Double { min(sprValue(idx), stdValue(idx)) }
    private func high(_ idx: Int) -> Double { max(sprValue(idx), stdValue(idx)) }

    private func bubble(at idx: Int) -> ValueBubble {
        let sprValue: Double? = idx < spr.count ? spr[idx] : nil
        let stdValue: Double? = idx < std.count ? std[idx] : nil
        let sprText: String = sprValue.map { Fmt.signedEur($0) } ?? "–"
        let stdText: String = stdValue.map { Fmt.signedEur($0) } ?? "–"
        var rows: [ValueBubble.Row] = [
            ValueBubble.Row(label: sprName, value: sprText, color: Theme.success),
            ValueBubble.Row(label: stdName, value: stdText, color: Theme.accent)
        ]
        if let a = sprValue, let b = stdValue {
            rows.append(ValueBubble.Row(label: "Differenz", value: Fmt.signedEur(a - b),
                                        color: a >= b ? Theme.success : Theme.warning))
        }
        return ValueBubble(title: monthLabel(idx), rows: rows)
    }

    @ChartContentBuilder
    private var baseArea: some ChartContent {
        ForEach(indices, id: \.self) { idx in
            AreaMark(x: .value("Monat", idx), yStart: .value("Null", 0), yEnd: .value("Gemeinsam", low(idx)),
                     series: .value("Fläche", "base"))
                .foregroundStyle(Theme.accent.opacity(0.38))
        }
    }

    /// Band between the lines where Sprinter is ahead (thickness 0 elsewhere, so it never jumps).
    @ChartContentBuilder
    private var sprinterBand: some ChartContent {
        ForEach(indices, id: \.self) { idx in
            AreaMark(x: .value("Monat", idx), yStart: .value("Von", low(idx)),
                     yEnd: .value("Bis", sprValue(idx) > stdValue(idx) ? high(idx) : low(idx)),
                     series: .value("Fläche", "sprinterBand"))
                .foregroundStyle(Theme.success.opacity(0.65))
        }
    }

    /// Band between the lines where Standard is ahead.
    @ChartContentBuilder
    private var standardBand: some ChartContent {
        ForEach(indices, id: \.self) { idx in
            AreaMark(x: .value("Monat", idx), yStart: .value("Von", low(idx)),
                     yEnd: .value("Bis", stdValue(idx) > sprValue(idx) ? high(idx) : low(idx)),
                     series: .value("Fläche", "standardBand"))
                .foregroundStyle(Theme.warning.opacity(0.65))
        }
    }

    @ChartContentBuilder
    private func edge(_ values: [Double], name: String, color: Color) -> some ChartContent {
        ForEach(Array(values.enumerated()), id: \.offset) { idx, v in
            LineMark(x: .value("Monat", idx), y: .value("Wert", v), series: .value("Linie", name))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.6))
        }
    }

    @ChartContentBuilder
    private var zeroRule: some ChartContent {
        if zeroDashed {
            RuleMark(y: .value("Null", 0)).foregroundStyle(zeroColor)
                .lineStyle(StrokeStyle(lineWidth: 1.3, dash: [5, 4]))
        } else {
            RuleMark(y: .value("Null", 0)).foregroundStyle(zeroColor)
        }
    }

    @ChartContentBuilder
    private var markerRule: some ChartContent {
        if let m = markerMonth, m <= maxIndex {
            RuleMark(x: .value("Marker", m))
                .foregroundStyle(markerColor.opacity(0.85))
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
        }
    }

    @ChartContentBuilder
    private func endDot(_ values: [Double], color: Color, show: Bool) -> some ChartContent {
        if show, let last = values.last {
            PointMark(x: .value("Monat", values.count - 1), y: .value("Wert", last))
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
            baseArea
            sprinterBand
            standardBand
            zeroRule
            markerRule
            edge(std, name: stdName, color: Theme.accent)
            edge(spr, name: sprName, color: Theme.success)
            endDot(std, color: Theme.accent, show: stdEndDot)
            endDot(spr, color: Theme.success, show: sprEndDot)
            selectionMark
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
        .frame(height: height)
    }

    private func swatch(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 10)
            Text(text).font(.caption)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                swatch(Theme.accent.opacity(0.5), "Gemeinsamer Stand")
                swatch(Theme.success.opacity(0.75), "\(sprName) vorn")
                swatch(Theme.warning.opacity(0.75), "\(stdName) vorn")
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Rectangle().fill(Theme.success).frame(width: 12, height: 3)
                    Text("Linie \(sprName)").font(.caption)
                }
                HStack(spacing: 4) {
                    Rectangle().fill(Theme.accent).frame(width: 12, height: 3)
                    Text("Linie \(stdName)").font(.caption)
                }
                if let label = markerLabel {
                    HStack(spacing: 4) {
                        Rectangle().fill(markerColor).frame(width: 12, height: 3)
                        Text(label).font(.caption)
                    }
                }
                if let label = zeroLabel {
                    HStack(spacing: 4) {
                        Rectangle().fill(zeroColor).frame(width: 12, height: 3)
                        Text(label).font(.caption)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            chart
            legend
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
                ? "\(monthLabelShort(seg.from)) – \(monthLabelShort(seg.to - 1)) · \(seg.months) Mon."
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
                        if let i = v.as(Int.self) { Text(monthLabelShort(i)).font(.system(size: 9)) }
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

/// Account balance for both scenarios as filled areas (see ComparisonAreaChart), a shared marker for the
/// Finanzamt refund in Oct. 2028, a dot where the money runs out, and a table with the key dates.
struct RunwayBalanceChart: View {
    let std: RunwayResult
    let spr: RunwayResult

    private let faMonth = 21   // Oct 2028

    private func endText(_ r: RunwayResult) -> String {
        r.exhaustedMonth < 240 ? monthLabel(r.curve.count - 1) : "> 20 Jahre"
    }

    private var datesTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                Text("")
                Text("Sprinter").font(.caption.weight(.bold)).foregroundStyle(Theme.success)
                Text("Standard").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
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
            ComparisonAreaChart(spr: spr.curve, std: std.curve,
                                markerMonth: faMonth, markerLabel: "FA \(monthLabel(faMonth))",
                                sprEndDot: spr.exhaustedMonth < 240, stdEndDot: std.exhaustedMonth < 240)
            datesTable
        }
    }
}
