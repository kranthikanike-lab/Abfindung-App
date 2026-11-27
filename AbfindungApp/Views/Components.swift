import SwiftUI

extension Color {
    /// Color that adapts to light and dark mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}

enum Theme {
    // App accent: teal in light mode; dark mode keeps the original blue and black look.
    static let accent = Color(light: Color(red: 0.059, green: 0.463, blue: 0.431),
                              dark: Color(red: 0.231, green: 0.510, blue: 0.965))
    // Data series blue (e.g. Standard scenario). Kept separate from the teal accent so series stay distinguishable.
    static let blue = Color(light: Color(red: 0.145, green: 0.388, blue: 0.922),
                            dark: Color(red: 0.231, green: 0.510, blue: 0.965))
    static let success = Color(light: Color(red: 0.020, green: 0.588, blue: 0.412),
                               dark: Color(red: 0.063, green: 0.725, blue: 0.506))
    static let warning = Color(light: Color(red: 0.851, green: 0.467, blue: 0.024),
                               dark: Color(red: 0.961, green: 0.620, blue: 0.043))
    static let danger = Color(light: Color(red: 0.863, green: 0.149, blue: 0.149),
                              dark: Color(red: 0.937, green: 0.267, blue: 0.267))
    static let purple = Color(light: Color(red: 0.486, green: 0.227, blue: 0.929),
                              dark: Color(red: 0.659, green: 0.333, blue: 0.969))
    static let cyan = Color(light: Color(red: 0.031, green: 0.569, blue: 0.698),
                            dark: Color(red: 0.024, green: 0.714, blue: 0.831))
    static let indigo = Color(red: 0.388, green: 0.4, blue: 0.945)
    static let orange = Color(red: 0.976, green: 0.451, blue: 0.086)
    static let yellow = Color(red: 0.918, green: 0.702, blue: 0.031)

    // Surfaces: soft teal-grey page, white cards (light mode); system colors in dark mode.
    static let pageBackground = Color(light: Color(red: 0.929, green: 0.949, blue: 0.949),
                                      dark: Color(.systemGroupedBackground))
    static let card = Color(light: .white, dark: Color(.secondarySystemGroupedBackground))
    static let field = Color(light: Color(red: 0.945, green: 0.965, blue: 0.965),
                             dark: Color(.tertiarySystemGroupedBackground))
    static let border = Color(light: Color(red: 0.059, green: 0.463, blue: 0.431).opacity(0.14),
                              dark: Color.clear)

    /// Horizontal space between the screen edge and the cards.
    static let pageMargin: CGFloat = 6
}

extension View {
    /// Card surface with a hairline border so white cards stay defined on the teal-grey page.
    func cardBackground(radius: CGFloat = 16) -> some View {
        self.background(Theme.card, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.border, lineWidth: 0.6))
    }

    /// Navigation bar and tab bar in the theme colors.
    func themedBars() -> some View {
        self.toolbarBackground(Theme.pageBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Theme.card, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

struct Card<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardBackground(radius: 16)
    }
}

/// "?" button that opens the tooltip text in a sheet.
struct InfoButton: View {
    let info: InfoText
    @State private var show = false
    var body: some View {
        Button { show = true } label: {
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $show) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringKey(info.text))
                        if Lang.shared.isEnglish {
                            Text(tr("Hinweis: Die Erläuterungstexte sind derzeit nur auf Deutsch verfügbar."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(info.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("Fertig")) { show = false } } }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

struct FieldLabel: View {
    let title: String
    var info: InfoText? = nil
    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.subheadline.weight(.medium))
            if let info { InfoButton(info: info) }
            Spacer(minLength: 0)
        }
    }
}

struct Hint: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text).font(.caption).foregroundStyle(.secondary) }
}

struct NumberField: View {
    let title: String
    @Binding var value: Double
    var info: InfoText? = nil
    var suffix: String = ""
    var hint: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(title: title, info: info)
            HStack {
                TextField("0", value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                if !suffix.isEmpty { Text(suffix).foregroundStyle(.secondary) }
            }
            .padding(10)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 10))
            if let hint { Hint(hint) }
        }
    }
}

extension Binding where Value == Int {
    /// Int binding as Double, e.g. for sliders.
    var asDouble: Binding<Double> {
        Binding<Double>(get: { Double(wrappedValue) }, set: { wrappedValue = Int($0.isFinite ? $0.rounded() : 0) })
    }
}

/// Slider with a tappable value: drag for quick changes, tap the number to type an exact value.
/// The slider range grows when a larger value is typed, so typed values are never clipped.
struct SliderField: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var info: InfoText? = nil
    var suffix: String = ""
    var decimals: Int = 0
    /// Read-only value text instead of a typing field (e.g. month names).
    var displayText: ((Double) -> String)? = nil
    var hint: String? = nil

    private var upper: Double {
        max(range.upperBound, (max(value, 0) / step).rounded(.up) * step)
    }

    private func label(_ v: Double) -> String {
        suffix == "€" ? Fmt.eur(v) : Fmt.decimal(v, digits: decimals) + (suffix.isEmpty ? "" : " " + suffix)
    }

    private var valueField: some View {
        HStack(spacing: 4) {
            TextField("0", value: $value, format: .number.precision(.fractionLength(0...max(decimals, 0))))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 70, maxWidth: 120)
            if !suffix.isEmpty { Text(suffix).foregroundStyle(.secondary) }
        }
        .font(.subheadline.weight(.bold))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                FieldLabel(title: title, info: info)
                if let displayText {
                    Text(displayText(value)).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent)
                } else {
                    valueField
                }
            }
            Slider(value: Binding(get: { min(max(value, range.lowerBound), upper) }, set: { value = $0 }),
                   in: range.lowerBound...upper, step: step)
            HStack {
                Text(displayText == nil ? label(range.lowerBound) : displayText!(range.lowerBound))
                Spacer()
                Text(displayText == nil ? label(upper) : displayText!(upper))
            }
            .font(.caption2).foregroundStyle(.secondary)
            if let hint { Hint(hint) }
        }
    }
}

struct IntField: View {
    let title: String
    @Binding var value: Int
    var info: InfoText? = nil
    var suffix: String = ""
    var hint: String? = nil
    var body: some View {
        NumberField(title: title,
                    value: Binding(get: { Double(value) }, set: { value = Int($0.isFinite ? $0 : 0) }),
                    info: info, suffix: suffix, hint: hint)
    }
}

struct KPITile: View {
    let label: String
    let value: String
    var sub: String? = nil
    var color: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Text(value).font(.title3.weight(.heavy)).foregroundStyle(color)
                .minimumScaleFactor(0.6).lineLimit(1)
            if let sub { Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(3) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardBackground(radius: 14)
    }
}

struct KPIGrid<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            content
        }
    }
}

struct Banner: View {
    let text: String
    var color: Color
    var body: some View {
        Text(LocalizedStringKey(text))
            .font(.footnote)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12))
            .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 4) }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SectionToggle<Content: View>: View {
    let title: String
    let badge: String
    @Binding var isOn: Bool
    @ViewBuilder var content: Content
    var body: some View {
        Card {
            Toggle(isOn: $isOn.animation()) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(badge).font(.caption).foregroundStyle(.secondary)
                }
            }
            if isOn { content }
        }
    }
}

struct SliderCard: View {
    let title: String
    var info: InfoText
    let valueText: String
    var pill: String? = nil
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var hint: String
    var sweetTitle: String? = nil
    var sweetAction: (() -> Void)? = nil
    var extraAction: (String, () -> Void)? = nil
    var explainLabel: String? = nil
    var explainValue: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { FieldLabel(title: title, info: info); Text(valueText).font(.subheadline.weight(.heavy)).foregroundStyle(Theme.accent) }
            if let pill { Text(pill).font(.caption.weight(.semibold)).foregroundStyle(Theme.success)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Theme.success.opacity(0.12), in: Capsule()) }
            Slider(value: $value, in: range, step: step)
            Hint(hint)
            HStack {
                if let sweetTitle, let sweetAction {
                    Button(sweetTitle, action: sweetAction).buttonStyle(.bordered).font(.caption).tint(Theme.accent)
                }
                if let extraAction {
                    Button(extraAction.0, action: extraAction.1).buttonStyle(.bordered).font(.caption).tint(Theme.accent)
                }
            }
            if let explainLabel, let explainValue {
                HStack(alignment: .top) {
                    Text(explainLabel).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(explainValue).font(.caption.weight(.bold))
                }
                .padding(8).background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Table row for the three result tables.
struct TableRow: View {
    let label: String
    let value: String
    var note: String? = nil
    var color: Color = .primary
    var bold = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.subheadline.weight(bold ? .bold : .regular))
                Spacer(minLength: 8)
                Text(value).font(.subheadline.weight(bold ? .heavy : .semibold)).foregroundStyle(color)
                    .monospacedDigit()
            }
            if let note { Text(note).font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 4)
    }
}

struct ResultTable<Content: View>: View {
    let title: String
    let summary: String
    var summaryColor: Color = Theme.accent
    @ViewBuilder var content: Content
    @State private var open = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $open) {
                Divider().padding(.vertical, 4)
                content
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(summary).font(.footnote.weight(.bold)).foregroundStyle(summaryColor)
                }
            }
        }
        .padding(14)
        .cardBackground(radius: 16)
    }
}

// MARK: - Pro tier

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.heavy))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.accent.opacity(0.15), in: Capsule())
            .foregroundStyle(Theme.accent)
    }
}

/// Teaser card shown instead of a Pro feature in the Basic version.
struct ProLockedCard: View {
    let feature: Feature
    var body: some View {
        Card {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill").foregroundStyle(Theme.accent)
                Text(feature.title).font(.headline)
                ProBadge()
                Spacer(minLength: 0)
            }
            Text(feature.summary).font(.subheadline).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(feature.bullets, id: \.self) { b in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Theme.success)
                        Text(b).font(.footnote)
                    }
                }
            }
            Button {
                AppSheets.shared.showUnlock = true
            } label: {
                Label(tr("Pro freischalten"), systemImage: "lock.open")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

/// Full-screen replacement for a Pro tab in the Basic version.
struct ProLockedView: View {
    let feature: Feature
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ProLockedCard(feature: feature)
                Card(title: tr("Beispielrechnung")) {
                    Text(feature.example).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.vertical, 12)
        }
        .background(Theme.pageBackground)
    }
}
