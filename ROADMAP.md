# Roadmap & open decisions

## Next features (one `feature/*` branch each, merged into `main` after green CI + phone test, then a `stable/*` marker)
1. `feature/chart-touch-values` – touch values on charts, new Reichweite balance chart (in progress)
2. `feature/teal-theme` – light mode: neutral teal-grey background, white cards, teal accent
3. `feature/english` – in-app language toggle (German / English), German terms kept where useful; tooltips and legal text may stay German
4. Release steps (last): StoreKit one-time purchase "Pro 2027", privacy policy, App Store page

## Reminder: web version / blog integration (decide after the features above are built)
Goal: calculators on a website or embedded in the author's blog. Decisions still open:
- Share the calculation logic: keep two implementations (JS + Swift) tied together by shared test scenarios (recommended), or one JS engine used by the app through JavaScriptCore
- What is free on the web (suggestion: Basic free, Pro as app upsell)
- Blog platform and embedding method (iframe, script/web component, one page per calculator)
- Hosting and per-branch previews (e.g. GitHub Pages)
- Website requirements: Impressum, Datenschutz, "keine Steuerberatung", visible "Stand" for the 2027 draft values, self-hosted Chart.js
Reference material already in the repo: `Reference/rechner_pro_v26_9.html` (original HTML calculator).

## Pending value updates
- 2027 income-tax values follow the Regierungsentwurf (BT-Drucksache 21/8235); update when the law is passed
- Pflegeversicherung 2027 childless surcharge (0,7 vs 0,9): currently the cautious 0,9
- Soli Freigrenze 20.350 € assumed unchanged
