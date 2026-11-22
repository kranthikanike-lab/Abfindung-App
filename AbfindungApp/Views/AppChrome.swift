import SwiftUI

enum ThemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { self == .system ? "System" : (self == .light ? "Hell" : "Dunkel") }
    var scheme: ColorScheme? { self == .light ? .light : (self == .dark ? .dark : nil) }
}

struct AppToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model
    @AppStorage("abfindungs_optimizer_theme_v2") private var themeRaw = ThemeChoice.system.rawValue

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Section("Schnell-Szenarien") {
                    Button("\(model.isPro ? "" : "🔒 ")🚀 Sprinter + Rürup Sweet-Spot") { model.apply(.sprinterSweet) }
                    Button("\(model.isPro ? "" : "🔒 ")🧭 Cash-Burn & Reichweite") { model.apply(.runwayCheck) }
                    Button("\(model.isPro ? "" : "🔒 ")📉 Gehalts-Switch (Break-Even)") { model.apply(.gehaltsSwitch) }
                    Button("↺ Reset", role: .destructive) { model.apply(.reset) }
                }
            } label: { Image(systemName: "bolt.circle") }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Darstellung", selection: $themeRaw) {
                    ForEach(ThemeChoice.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Divider()
                Button { AppSheets.shared.showLegal = true } label: { Label("Rechengrößen & Recht 2027", systemImage: "info.circle") }
                if model.isPro {
                    ShareLink(item: ReportFile(results: model.results, inputs: model.inputs),
                              preview: SharePreview("Abfindungs-Report.pdf")) {
                        Label("Report / PDF", systemImage: "doc.richtext")
                    }
                } else {
                    Button { AppSheets.shared.showUnlock = true } label: {
                        Label("Report / PDF (Pro)", systemImage: "lock")
                    }
                }
                Divider()
                Button { AppSheets.shared.showUnlock = true } label: {
                    Label(model.isPro ? "Pro aktiv" : "Pro freischalten", systemImage: model.isPro ? "checkmark.seal" : "lock.open")
                }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }
}

@Observable
final class AppSheets {
    static let shared = AppSheets()
    var showLegal = false
    var showUnlock = false
}

struct StickyKPIBar: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let r = model.results
        HStack {
            item("Sofort-Netto", Fmt.eur(r.netVoll), .primary)
            Divider().frame(height: 28)
            item(r.erstattung >= 0 ? "FA Okt. 2028" : "Nachzahlung FA", Fmt.signedEur(r.erstattung),
                 r.erstattung >= 0 ? Theme.success : Theme.danger)
            Divider().frame(height: 28)
            item("Optimal-Netto", Fmt.eur(r.netFf), Theme.accent)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }
    private func item(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(spacing: 1) {
            Text(l).font(.caption2).foregroundStyle(.secondary)
            Text(v).font(.subheadline.weight(.heavy)).foregroundStyle(c).minimumScaleFactor(0.6).lineLimit(1)
        }.frame(maxWidth: .infinity)
    }
}

struct LegalSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(Info.legal, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0).font(.subheadline.weight(.semibold))
                        Text(item.1).font(.footnote).foregroundStyle(.secondary)
                    }.padding(.vertical, 2)
                }
                Section("Annahmen & Stand") {
                    ForEach(Info.assumptions, id: \.0) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.0).font(.subheadline.weight(.semibold))
                            Text(item.1).font(.footnote).foregroundStyle(.secondary)
                        }.padding(.vertical, 2)
                    }
                }
                Section {
                    Text("Unverbindliche Modellrechnung ohne Gewähr. Ersetzt keine Steuer- oder Rechtsberatung.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Rechengrößen & Recht 2027")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Schließen") { dismiss() } } }
        }
    }
}

struct DrvDeficitSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var points = 45.0
    @State private var penalty = 0.144
    @State private var pointCost = 9942.07

    private var missing: Double { penalty >= 1 ? 0 : points * penalty / (1 - penalty) }
    private var cost: Double { missing * pointCost }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Berechnen Sie die Einmalzahlung, die nötig ist, um den lebenslangen Rentenabschlag (0,3 % je Monat, höchstens 14,4 % bei 4 Jahren Frührente) auszugleichen. Maßgeblich sind die Rentenpunkte, die Sie bei Rentenbeginn voraussichtlich haben.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Rentenpunkte bei Rentenbeginn (Prognose laut Rentenauskunft)") {
                    TextField("45", value: $points, format: .number).keyboardType(.decimalPad)
                }
                Section("Geplanter Rentenabschlag") {
                    Picker("Abschlag", selection: $penalty) {
                        Text("1 Jahr (3,6 %)").tag(0.036)
                        Text("2 Jahre (7,2 %)").tag(0.072)
                        Text("3 Jahre (10,8 %)").tag(0.108)
                        Text("4 Jahre (14,4 %)").tag(0.144)
                    }.pickerStyle(.menu)
                }
                Section("Einzahlungsjahr (Kaufpreis pro Punkt)") {
                    Picker("Jahr", selection: $pointCost) {
                        Text("2026 (~9.661 € / Punkt)").tag(9661.58)
                        Text("2027 (~9.942 € / Punkt)").tag(9942.07)
                    }.pickerStyle(.segmented)
                }
                Section {
                    LabeledContent("Erforderlicher Nachkauf") {
                        Text(String(format: "%.2f", locale: Locale(identifier: "de_DE"), missing) + " Punkte").bold()
                    }
                    LabeledContent("Notwendige Einmalzahlung (V0210)") {
                        Text(Fmt.eur(cost)).font(.title3.weight(.heavy)).foregroundStyle(Theme.accent)
                    }
                }
                Section {
                    Button("In Steuer-Optimierung übernehmen (Sektion B)") {
                        model.applyDrvDeficit(cost: jsRound(cost))
                        dismiss()
                    }
                }
            }
            .navigationTitle("🎯 Rentenpunkte-Defizit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}


/// Explains the Pro tier. The purchase itself is added before release; until then a test switch is shown.
struct UnlockSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text("Abfindungs-Optimizer Pro").font(.title3.weight(.bold)); ProBadge() }
                        Text("Einmaliger Kauf für 2027. Der Preis wird vor der Veröffentlichung festgelegt.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
                Section("Enthalten in Pro") {
                    ForEach(Feature.allCases) { f in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: f.icon).frame(width: 24).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.title).font(.subheadline.weight(.semibold))
                                Text(f.summary).font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 2)
                    }
                }
                Section("Immer kostenlos (Basic)") {
                    Text("Abfindung, Lohnsteuer-Einbehalt, Fünftelregelung und Erstattung, Kinder, Splitting, Kirchensteuer, Sprinter-Option, Ergebnistabellen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if Entitlements.testMode {
                    Section {
                        if model.isPro {
                            Button("Auf Basic zurücksetzen (Testmodus)", role: .destructive) { model.isPro = false; dismiss() }
                        } else {
                            Button("Pro freischalten (Testmodus)") { model.isPro = true; dismiss() }
                        }
                    } footer: {
                        Text("Testmodus: In der veröffentlichten Version wird dies durch den Einmalkauf über den App Store ersetzt.")
                    }
                }
            }
            .navigationTitle("Pro 2027")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }
    }
}
