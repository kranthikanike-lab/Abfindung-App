import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("abfindungs_optimizer_theme_v2") private var themeRaw = ThemeChoice.system.rawValue

    var body: some View {
        @Bindable var m = model
        @Bindable var sheets = AppSheets.shared
        TabView(selection: $m.selectedTab) {
            NavigationStack { InputsView() }
                .tabItem { Label(tr("Eingaben"), systemImage: "slider.horizontal.3") }
                .tag(AppTab.inputs)
            NavigationStack { OptimizationView() }
                .tabItem { Label(tr("Steuer"), systemImage: "percent") }
                .tag(AppTab.optimization)
            NavigationStack { ResultsView() }
                .tabItem { Label(tr("Ergebnis"), systemImage: "chart.pie") }
                .tag(AppTab.results)
            NavigationStack { RunwayView() }
                .tabItem { Label(tr("Reichweite"), systemImage: "hourglass") }
                .tag(AppTab.runway)
            NavigationStack { CrossoverView() }
                .tabItem { Label("Switch", systemImage: "arrow.left.arrow.right") }
                .tag(AppTab.crossover)
        }
        .preferredColorScheme(ThemeChoice(rawValue: themeRaw)?.scheme)
        .sheet(isPresented: $sheets.showLegal) { LegalSheet() }
        .sheet(isPresented: $sheets.showUnlock) { UnlockSheet() }
    }
}
