## v2.2.0 - October 2026

### Plan advisor: "What plan should I choose?"

- A new section under the headline block answers the inverse question: given what you know (people available, a deadline, a budget, or nothing), which team and schedule should you choose? The planner prices every team size from 1 to 8 against every schedule cap through the same engine, so each card is an exact engine call: **Apply** sets the caps in the sidebar and the headline reproduces the card to the dollar (Undo offered); **Save as scenario** pins it.
- Cards: with your team (plus what one more or one fewer person changes), for your deadline (smallest team and its premium), fastest within your budget, cheapest, fastest practical. Unmet deadlines name the nearest achievable date and team; unmet budgets say how much of the scope would fit and what one level better code reuse or tooling would save.
- A staffing curve: fastest practical months and the natural schedule for one to eight people, cost on each point, the practical floor at 75% of the natural schedule (Boehm's "impossible region", COCOMO II's SCED limit), and the coordination-overhead zone from six people.
- Plain-language advice generated from the computed numbers, no AI involved, ending with the range caveat. The PDF gains a "Plan options" page; share links carry the three facts.
- The schedule cap now runs from 3 to 60 months in 1-month steps so long, small-team plans can be applied.

## v2.1.0 - October 2026

### A clearer, calmer estimate

- **One page for the estimate.** Home, Analyze and Export are now a single Estimate page: inputs on the left, the result on the right. Sub-tabs are replaced by sections named for the question they answer (How is the cost built? What if the deadline moves?). The first two are open; the rest are one click away.
- **The headline block.** A serif figure with its ±30% range drawn on a scale from $0, a status line in words (Within plan, Compressed schedule, Not feasible with this team cap), three tiles each with their reference and basis, and a scope line saying what the number rests on.
- **First-run screen.** Instead of empty chart frames, a worked example you can run with one click and the three ways to bring in code.
- **Live recalculation.** Line counts and uploads need Run estimate; every other input updates the result as you change it, and the page says so.
- **Plain-language inputs.** Reuse, tooling and the five COCOMO drivers are named rating levels (Excellent tooling, Very high reliability) mapped to the published multipliers, instead of 0.01-step sliders. Every input has a real label and a help popover. Reset returns the defaults with Undo. Validation appears next to the field, and scan failures show a typed error state with the reason.
- **Scenarios** are saved from the estimate (Save as scenario) rather than retyped. Each one is editable in place, recalculates live and shows when it has drifted from what was saved. Aligned bars and a side-by-side table with the difference against Scenario 1.
- **Light and dark mode**, self-hosted Source Sans 3 and Source Serif 4, a new petrol palette with cost-up (copper) and cost-down (green) roles that pass contrast in both modes, keyboard focus rings, a skip link, reduced-motion support and a phone layout without horizontal scroll.

### Every view tells the same story

- **One cost decomposition.** The waterfall, the ranked drivers, the text report, the CSV and the PDF all read the same cost steps, which sum exactly to the headline. Previously the ranked bars used a different calculation from the waterfall.
- **Tradeoff curve.** The marker now sits on the curve at your schedule cap; caps shorter than the natural schedule are shaded and infeasible caps are hollow. The curve covers every cap the slider offers.
- **Total cost of ownership** is labelled by its basis everywhere; the ownership chart draws nominal and today's dollars as two lines.
- **Share links** carry every input that moves the number (all six line counts, every parameter, maintenance), are generated from the live values, and the address bar is always the link. Repository scans share as their line counts.
- **Rounded for display.** Figures are shown to the nearest $1,000 (nearest $100 below $100,000) so a ±30% estimate never reads as dollar-accurate; the engine is unchanged and golden tests still pass.
- Defaults aligned: the worked example and the inputs both use team experience 4; team cap stops at 8 (the engine's limit); maintenance years default to 3 so TCO is a first-class output.

### PDF report

- New type and palette matching the app, labelled waterfall and ranked drivers from the shared cost steps, corrected tradeoff marker, nominal and today's-dollar ownership lines, rating level names in the assumptions table, a cost-steps table, and display rounding identical to the screen.

### Under the hood

- `modules/ui_helpers.R` holds the contract components (KPI tile that refuses a bare number, typed state panel that requires a reason, question-named section, labelled field with help) with unit tests; `modules/app_helpers.R` gains the share-link round trip, display formatting, rating levels and the shared cost decomposition, all tested. 297 assertions across 9 files.
- The export module folded into the hero toolbar; one PDF handler instead of two.

## v2.0.0 - July 2026

### Branded PDF Reports

- **One-click PDF report** (Export tab and summary strip) — a client-ready document with cover page, headline estimate and range, cost breakdown and driver charts, schedule/TCO analysis, assumptions table, and methodology notes
- Rendered with Quarto + Typst (no LaTeX or Chrome needed), fully compatible with shinyapps.io

### Model Corrections (COCOMO II.2000 alignment)

- Constants aligned with published COCOMO II.2000: A = 2.94, C = 3.67, and the schedule exponent now anchored at B = 0.91 (the previous 1.01 anchor systematically shortened schedules). The 15% modern-framework calibration is now applied exactly once and documented
- **Consistent numbers**: displayed effort now always equals team size × schedule, including under schedule compression
- **Smooth compression premium**: the discrete 20/40/70/100% premium ladder (which created cost cliffs of up to 42% from a one-month schedule change) is replaced by a continuous premium anchored to COCOMO II's SCED driver, capped at +100%
- **One wage rate**: the hardcoded $12k/month internal rate is gone; every figure (including the waterfall chart) now derives from your wage input
- **Honest uncertainty language**: the ±30% band is now labeled "Estimate range", not a confidence interval
- **Discounted TCO**: multi-year maintenance is reported both nominally and in present value (default 5%/yr discount rate); TCO uses present value
- **Docs excluded from billing**: Markdown, JSON, YAML, SVG, and other non-code files are shown in the analysis but no longer inflate the estimate
- Feasibility flag: when a compressed schedule would need more people than your team cap, the app says so explicitly

### Chart Fixes

- Waterfall chart now totals exactly the headline cost and includes explicit schedule-compression and coordination steps
- Driver-impact chart units corrected (bars were inflated by the schedule length)
- Sensitivity curves now include all advanced drivers and pass through your actual estimate, with a marker at your current position
- Comparison chart split into three panels (cost, schedule, team) with proper axes; shared wage/schedule inputs keep scenarios comparable

### Light Professional Redesign

- New light theme with a single design-token source of truth (`modules/theme.R` + `www/custom.css`) driving the app, all charts, and the PDF report
- Unified KPI cards replace the multicolor value boxes; the estimate range indicator now shows real low/mid/high ticks
- Language treemap uses the brand palette, with non-billable languages greyed out
- Inter typography throughout

### Robustness

- Blank or invalid Manual Entry fields no longer crash the analysis
- Shared-URL parameters are validated and bounds-checked
- 50MB upload limit actually enforced (previously capped at Shiny's 5MB default)
- Input validation added for wage, team size, schedule, and discount rate
- Test suite expanded from 59 to ~180 assertions, including golden-value and model-invariant tests

### Removed

- AI Assistant tab (client-facing deployments should not carry API-key cost/risk)

---

## v1.0.1 - February 2026

### Interactive Web App

- **Hero dashboard layout** with KPI value boxes (cost, schedule, team size, confidence range) displayed prominently at the top of each analysis view
- **Waterfall cost breakdown chart** showing how base effort flows through each multiplier (experience, reuse, tools, modern framework, COCOMO drivers) to reach the final estimate. Bars are ordered from base effort on the left to total cost on the right
- **Modular architecture** with dedicated modules for analysis results, scenario comparison, and export functionality

### COCOMO II Cost Drivers

- **Five advanced drivers** added to the sidebar: Required Reliability (RELY), Product Complexity (CPLX), Required Reusability (RUSE), Personnel Continuity (PCON), and Application Experience (APEX)
- Each driver has its own slider with the standard COCOMO II range, defaulting to 1.0 (nominal)
- Drivers are multiplied into the effort calculation and reflected in the waterfall chart

### Maintenance & TCO Projections

- **Annual maintenance rate** slider (0-40% of build cost)
- **Maintenance years** slider (0-10 years)
- Annual costs compound at 5% per year to account for knowledge turnover
- Dedicated **Maintenance sub-tab** with year-by-year breakdown and Total Cost of Ownership

### Scenario Comparison

- Compare up to **3 scenarios** side-by-side in the Compare tab
- Each scenario has independent parameter controls including tool support
- Results displayed in a comparative table for quick decision-making

### Export & Sharing

- **Shareable URLs** with proper protocol detection (http/https) and pre-filled Manual Entry parameters
- **CSV export** of analysis results
- **JSON export** for programmatic consumption

### User Interface

- **User Guide** and **Release Notes** accessible from navbar buttons (replacing the GitHub link)
- **App footer** with version number and author credit
- Dark theme (Bootswatch Darkly) with Roboto font throughout
- Sensitivity analysis charts for exploring parameter impact interactively

### Bug Fixes

- Fixed waterfall chart bar ordering so bars flow logically from base effort through multipliers to total
- Fixed invisible effort value box that was unreadable on the dark theme
- Fixed comment double-counting in repository analysis by using single-pass OR across patterns
