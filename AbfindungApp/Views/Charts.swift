import SwiftUI
import Charts

struct DonutChart: View {
    struct Slice: Identifiable { let id = UUID(); let name: String; let value: Double; let color: Color }
    let slices: [Slice]
    var body: some View {
        Chart(slices) { s in
            SectorMark(angle: .value("Betrag", max(0, s.value)), innerRadius: .ratio(0.6), angularInset: 1.5)
                .foregroundStyle(s.color)
                .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .frame(height: 170)
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

struct AgChart: View {
    let r: Results
    var body: some View {
        let slices = [DonutChart.Slice(name: "Sofort-Netto", value: r.netVoll, color: Theme.accent),
                      DonutChart.Slice(name: "Lohnsteuer-Einbehalt", value: r.einbehalten, color: Theme.danger)]
        VStack { DonutChart(slices: slices)
            LegendRow(items: [("Sofort-Netto", Theme.accent, Fmt.eur(r.netVoll)),
                              ("Lohnsteuer-Einbehalt", Theme.danger, Fmt.eur(r.einbehalten))]) }
    }
}

struct FaChart: View {
    let r: Results
    var body: some View {
        let slices = [DonutChart.Slice(name: "Optimal-Netto", value: r.netFf, color: Theme.success),
                      DonutChart.Slice(name: "Endgültige Steuer", value: r.finalAbfTax, color: Theme.warning)]
        VStack { DonutChart(slices: slices)
            LegendRow(items: [("Optimal-Netto", Theme.success, Fmt.eur(r.netFf)),
                              ("Endgültige Steuer", Theme.warning, Fmt.eur(r.finalAbfTax))]) }
    }
}

struct ErstattungChart: View {
    let r: Results
    var body: some View {
        let bars: [(String, Double, Color)] = [
            ("Fünftel-Basis", r.baseFuenftelRefund, Theme.accent),
            ("DRV (50% Fünftel)", r.drvFuenftelRefund2028, Theme.cyan),
            ("Rürup", r.ruerupSaving.savings, Theme.success),
            ("PV-IAB", r.iabSaving.savings, Theme.purple)
        ]
        let shown = bars.filter { $0.1 != 0 || $0.0 == "Fünftel-Basis" }
        Chart(Array(shown.enumerated()), id: \.offset) { _, b in
            BarMark(x: .value("Quelle", b.0), y: .value("€", b.1))
                .foregroundStyle(b.2).cornerRadius(6)
        }
        .chartLegend(.hidden)
        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 9)) } }
        .frame(height: 190)
    }
}

struct SprinterWaterfall: View {
    let r: Results
    private struct Bar: Identifiable { var id: String { name }; let name: String; let lo: Double; let hi: Double; let color: Color }
    private var bars: [Bar] {
        var run = 0.0
        var bars: [Bar] = []
        bars.append(Bar(name: "+ Netto-Prämie", lo: 0, hi: r.isolatedNettoPraemie, color: Theme.accent)); run += r.isolatedNettoPraemie
        bars.append(Bar(name: "+ Fünftel-Steuer", lo: run, hi: run + r.pureFuenftelAdvantage, color: Theme.success)); run += r.pureFuenftelAdvantage
        bars.append(Bar(name: "− Netto-Gehalt", lo: run - r.lostNetSalary, hi: run, color: Theme.danger)); run -= r.lostNetSalary
        bars.append(Bar(name: "− GKV/PV Lücke", lo: run - r.gkvTurboSim, hi: run, color: Theme.orange)); run -= r.gkvTurboSim
        let rvAlg = r.rvSim + r.alg1Sim
        bars.append(Bar(name: "− RV & ALG-1", lo: run - rvAlg, hi: run, color: Theme.yellow)); run -= rvAlg
        let d = r.sprinterNetDiff
        bars.append(Bar(name: "= ECHTER VORTEIL", lo: min(0, d), hi: max(0, d), color: d >= 0 ? Theme.success : Theme.danger))
        _ = run
        return bars
    }
    var body: some View {
        Chart(bars) { b in
            BarMark(xStart: .value("von", b.lo), xEnd: .value("bis", b.hi), y: .value("Posten", b.name))
                .foregroundStyle(b.color).cornerRadius(4)
        }
        .chartYScale(domain: bars.map { $0.name })
        .chartYAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 10)) } }
        .frame(height: 230)
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
    var body: some View {
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
        }
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
    }
}

struct PhaseChart: View {
    let std: RunwayResult
    let spr: RunwayResult
    private struct Seg: Identifiable { let id = UUID(); let scenario: String; let phase: String; let months: Int }
    var body: some View {
        let phases = ["1. Gehaltsphase", "2. Ruhenszeit (GKV)", "3. ALG-1 Bezug", "4. Privatiers-Phase"]
        let colors = [Theme.indigo, Theme.warning, Theme.cyan, Theme.success]
        let segs: [Seg] = [
            Seg(scenario: "Standard (Frist)", phase: phases[0], months: std.salMonthsTotal),
            Seg(scenario: "Standard (Frist)", phase: phases[1], months: std.dynamicRuhens),
            Seg(scenario: "Standard (Frist)", phase: phases[2], months: std.algMonths),
            Seg(scenario: "Standard (Frist)", phase: phases[3], months: std.postPhaseMonths),
            Seg(scenario: "Sprinter (Sofort)", phase: phases[0], months: spr.salMonthsTotal),
            Seg(scenario: "Sprinter (Sofort)", phase: phases[1], months: spr.dynamicRuhens),
            Seg(scenario: "Sprinter (Sofort)", phase: phases[2], months: spr.algMonths),
            Seg(scenario: "Sprinter (Sofort)", phase: phases[3], months: spr.postPhaseMonths)
        ]
        Chart(segs) { s in
            BarMark(x: .value("Monate", s.months), y: .value("Szenario", s.scenario))
                .foregroundStyle(by: .value("Phase", s.phase))
        }
        .chartForegroundStyleScale(domain: phases, range: colors)
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 170)
    }
}
