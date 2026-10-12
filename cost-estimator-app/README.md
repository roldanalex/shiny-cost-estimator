# Software Cost Estimator: Interactive App

A client-facing R Shiny application that estimates the development cost, schedule, team size and total cost of ownership of **any software project, in any language**, with a calibrated **COCOMO II.2000** model, and produces a **PDF report** your users can forward. It began as the Shiny Cost Estimator for R Shiny and data-science teams; the engine was always language-agnostic.

**Version 2.2.0** · Light and dark themes · Self-hosted Source Sans 3 / Source Serif 4 · Quarto + Typst PDF reports · shinyapps.io-ready

---

## Quick start

```r
# From the repository root
shiny::runApp("cost-estimator-app")

# Or with the launcher
Rscript cost-estimator-app/run_app.R
```

Check dependencies first:

```r
source("cost-estimator-app/check_dependencies.R")
```

Required: `shiny`, `bslib` (0.12 or later), `plotly`, `DT`, `markdown`, `jsonlite`, `quarto`, `ggplot2`, `knitr`, `ragg`, plus the [Quarto CLI](https://quarto.org) 1.3 or later for PDF reports (Typst is bundled with Quarto; no LaTeX or Chrome needed).

---

## The app

Two pages and a Help menu:

| Page | What it does |
|---|---|
| **Estimate** | Inputs on the left (source, project, money and limits, advanced drivers, maintenance); the result on the right |
| **Scenarios** | Up to three estimates saved from the Estimate page, editable in place, compared on aligned bars and a table |

**Plan advisor.** The first section under the headline (`modules/plan_helpers.R`) prices every team size (1 to 8) against every schedule cap through `run_estimate()`, recommends plans from what the user knows (people, deadline, budget), explains unmet targets (nearest date, scope that fits, levers), draws a staffing curve with the 75% practical floor, and writes plain-language advice from the computed numbers. Apply sets the sidebar caps; Save pins a scenario; the PDF has a plan page.

**Interaction model.** Line counts, ZIP uploads and folder scans need *Run estimate*; every other input recalculates the estimate live, and the page says so. *Reset* returns the defaults with *Undo*. Validation appears next to the field; scan failures show a typed error state with the reason.

**The result.** A headline block (serif figure, ±30% range on a scale from $0, a status line in words, schedule / team / TCO tiles each with their reference and basis, a scope line, and the actions: PDF, Save as scenario, Copy link, CSV, JSON), followed by sections named for the question they answer:

- How is the cost built? (labelled waterfall)
- What if the deadline moves? (cost at every schedule cap, marker at your cap, shaded compression, hollow infeasible caps)
- Which choices matter most? (the waterfall's steps, ranked)
- What is the code made of? (sorted bars, grey for not billed)
- How sensitive is the estimate? (team experience × complexity)
- What does it cost to keep running? (maintenance, nominal and today's dollars, TCO at other rates)
- Assumptions and data (table and text report)

A summary strip appears at the bottom only while the headline block is scrolled out of view.

**Kind of code.** *Modern framework or high-level language* applies the documented 0.85 calibration (default); *Systems, embedded or legacy code* keeps the published COCOMO II constant. The engine argument is `framework = "modern" | "systems"`; the waterfall shows the step as "Framework calibration".

**Inputs.** Reuse, tooling and the five COCOMO drivers are named rating levels mapped to the published multipliers (`RATING_LEVELS` in `modules/app_helpers.R`). Every input has a real label and a help popover.

**Share links.** The address bar always holds a link that reopens the exact estimate (every line count and parameter, bounds-checked on the way back in). Repository scans share as their line counts.

### Input sources

- **Manual**: pick languages from a list (21 weighted languages plus Other) and type line counts per language
- **ZIP**: upload a repository ZIP (max 50 MB), extracted in an isolated temp directory with path-traversal validation
- **Folder**: scan a project directory (hidden on deployed servers)

Repository scans classify documentation and config files (Markdown, JSON, YAML, SVG, …) as **non-billable**: shown, never counted.

---

## The model

```
Effort = 2.94 × KLOC^B × EM_total × 0.85
```

- `KLOC`: thousands of productivity-weighted billable code lines
- `B`: 1.02 / 1.10 / 1.18 for low / medium / high complexity
- `EM_total`: product of effort multipliers (experience, reuse, tools, RELY, CPLX, RUSE, PCON, APEX)
- `0.85`: documented calibration for modern high-level frameworks
- Schedule: `TDEV = 3.67 × Effort^D`, `D = 0.28 + 0.2 × (B − 0.91)` (COCOMO II.2000)
- Schedule compression: smooth premium `ratio^1.25` capped at 2.0×; infeasible plans are flagged
- Cost = effort × (annual wage ÷ 12); teams of 6 or more carry a 10% coordination overhead
- The ±30% band is an **estimate range** (typical COCOMO II accuracy), not a statistical confidence interval
- TCO: maintenance escalates 5%/yr and is discounted to today's dollars (default 5%/yr)

**One decomposition.** `cost_steps()` (`modules/app_helpers.R`) turns an estimate into base effort → each factor → premiums → final cost. The waterfall, the ranked drivers, the text report, the CSV and the PDF all read it, and it sums exactly to the headline. Figures are rounded for display (`fmt_usd()`); the engine is exact.

## PDF report

The *Download PDF report* button (and the strip) renders a five-page PDF:

1. **Cover**: logo, project name, date, headline cost and range, status
2. **Estimate summary**: tiles, status, labelled waterfall, ranked drivers
3. **Schedule and ownership**: tradeoff curve, ownership over time, assumptions table
4. **How the cost is built**: the cost-steps table
5. **Methodology**: formulas, constants, what the range means

Rendered server-side with **Quarto + Typst** (`report/estimate_report.qmd`), ggplot2 chart re-renders, and the bundled fonts. Colours and number formatting come from the same tokens and helpers as the app.

---

## Architecture

```
cost-estimator-app/
├── app.R                     # UI + server, sources everything below
├── modules/
│   ├── theme.R               # Design tokens: light + dark palettes, fonts, plotly base
│   ├── app_helpers.R         # Pure helpers: formatting, defaults, rating levels,
│   │                         #   share-link round trip, cost_steps() (unit-tested)
│   ├── plan_helpers.R        # Plan advisor: grid, recommendations, staffing curve, narrative (unit-tested)
│   ├── ui_helpers.R          # Contract components: kpi_tile, state_panel, question_section,
│   │                         #   field_with_help, hero_estimate, range_band (unit-tested)
│   ├── pdf_report.R          # Quarto render pipeline + download handler
│   ├── analysis_module.R     # Estimate page results: first run, hero, sections, strip, exports
│   ├── comparison_module.R   # Scenarios
│   ├── shiny_cost_estimator.R  # BUILD ARTIFACT - synced copy of ../R/
│   └── repo_code_analyzer.R    # BUILD ARTIFACT - synced copy of ../R/
├── report/                   # Quarto + Typst PDF report
│   ├── estimate_report.qmd
│   ├── report_charts.R       # ggplot2 chart re-renders
│   ├── logo.svg
│   └── fonts/                # Source Sans 3 + Source Serif 4 (TTF, for Typst)
├── www/
│   ├── custom.css            # Layered stylesheet; every colour is a --app-* variable
│   ├── fonts.css, fonts/     # Self-hosted woff2 fonts
│   ├── app.js                # Strip visibility, details resize, copy link, phone drawer
│   └── favicon.svg
└── markdown/                 # In-app manual, user guide, release notes
```

**Design tokens:** every colour lives in `modules/theme.R` (`app_palettes`, light and dark). bslib reads `app_theme()`, the CSS reads the generated `--app-*` variables (dark values under `[data-bs-theme="dark"]`, toggled per session by `bslib::input_dark_mode()`), plotly charts read `app_palette(mode)` through `app_plotly_base(mode)`, and the PDF receives the light palette. Change a hex once; everything follows. No hex values outside `theme.R`.

**UX contracts:** a KPI tile refuses to render without a reference and n; an empty or error view must say which kind it is and why; sections are named as questions; every input has a real `<label>` and a popover with an accessible name; status is always a word, never colour alone.

**Engine sync:** the canonical model lives in `../R/`. The copies in `modules/` are build artifacts refreshed by `Rscript tools/sync_modules.R` (a test fails if they drift). Deploy with `Rscript tools/deploy.R`, which syncs first.

---

## Testing

```bash
Rscript tests/testthat.R   # from the repository root
```

440 assertions: golden values, model invariants (effort ≡ team × schedule, cost continuity, wage linearity), input validation, analyzer billable classification, helper formatting and rating levels, share-link round trip to the dollar, `cost_steps()` summing to the headline, UI-helper contracts, a `testServer` smoke test and an end-to-end PDF render.

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md). Short version:

```r
# One-time
rsconnect::setAccountInfo(...)

# Every deploy (syncs engine copies, then deploys)
Rscript tools/deploy.R
```

On shinyapps.io the Folder source is hidden automatically and PDF rendering uses the Quarto CLI provisioned by the platform; smoke-test the PDF button after your first deploy.

---

MIT License · Created by Alexis Roldan
