import SwiftUI

enum Theme {
    static let accent = Color(red: 0.231, green: 0.510, blue: 0.965)
    static let success = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let danger = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let purple = Color(red: 0.659, green: 0.333, blue: 0.969)
    static let cyan = Color(red: 0.024, green: 0.714, blue: 0.831)
    static let indigo = Color(red: 0.388, green: 0.4, blue: 0.945)
    static let orange = Color(red: 0.976, green: 0.451, blue: 0.086)
    static let yellow = Color(red: 0.918, green: 0.702, blue: 0.031)
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
                    Text(LocalizedStringKey(info.text)).padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(info.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { show = false } } }
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
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
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
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
                Label("Pro freischalten", systemImage: "lock.open")
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
                Card(title: "Beispielrechnung") {
                    Text(feature.example).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
