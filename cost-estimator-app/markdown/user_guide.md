## Overview

The Software Cost Estimator uses the **COCOMO II** (Constructive Cost Model) methodology to estimate the cost, schedule, team size and budget required for any software project, in any language. It analyses your codebase or accepts manual line counts, then applies the published parametric model to produce an estimate with an honest range.

**What it estimates:**

- Development cost (USD) with an estimate range (±30%)
- Schedule (months) against your cap
- Team size (full-time equivalents) against your cap
- Maintenance costs and total cost of ownership (TCO)

---

## Where is the code?

The selector at the top of the sidebar picks one of three sources.

### Manual

Pick the languages from the **Languages** list (R, Python, JavaScript, TypeScript, SQL, HTML, CSS, Sass, Java, C#, Go, Rust, C, C++, Kotlin, Swift, Scala, Ruby, PHP, Julia, Shell, or Other for anything unlisted). A line-count box appears for each one; counts you typed are kept if you remove and re-add a language. Choose **Run estimate**.

### ZIP

Upload a `.zip` of the repository (max 50 MB). Files are extracted in an isolated temporary folder, counted, and discarded. Choose **Run estimate**.

### Folder

Only available when the app runs on your own computer. Enter or browse to the repository path and choose **Run estimate**.

Documentation and configuration files (Markdown, JSON, YAML, SVG, …) are shown in the results but never counted toward the cost. Each language carries a productivity weight relative to R (for example SQL 1.3, Python 1.1, JavaScript 0.9); unlisted languages count at 1.0. The full table is in the README.

> **Live recalculation.** Only the source inputs need *Run estimate*. Every parameter below recalculates the estimate the moment it changes.

---

## The project

| Input | Choices | Default | What it controls |
|---|---|---|---|
| What kind of code? | Modern framework or high-level language / Systems, embedded or legacy code | Modern framework | Whether the documented 0.85 modern-framework calibration applies; systems code keeps the published COCOMO II constant |
| Complexity | Low / Medium / High | Medium | Architectural complexity; drives the size exponent |
| Team experience | 1 (Novice) to 5 (Expert) | 4 (Proficient) | Average team skill |
| Code reuse | Very high reuse … None | Typical (1.00) | How much existing code can be leaned on |
| Tooling and process | Excellent … Poor | Standard (1.00) | Quality of IDE, version control, CI/CD, tests, review |

Code reuse and tooling are chosen as named levels. Each level maps to a published effort multiplier (shown in the Assumptions section).

## Money and limits

| Input | Range | Default | What it controls |
|---|---|---|---|
| Cost per developer-year | $50,000 to $300,000 | $105,000 | Fully loaded annual cost of one developer; converts effort to money |
| Team cap | 1 to 8 people | 5 | The most people on the project at once (6+ adds a 10% coordination premium) |
| Schedule cap | 3 to 60 months | 24 | The longest the project may take; tighter caps add a compression premium |

---

## Advanced COCOMO drivers

Expand **Advanced COCOMO drivers** in the sidebar. Each driver is a named rating level from COCOMO II.2000; the badge next to the heading shows their combined effect.

| Driver | Levels | What it controls |
|---|---|---|
| Required reliability | Very low (0.82) to Very high (1.26) | Cost of a failure |
| Product complexity | Very low (0.73) to Extra high (1.74) | Algorithmic and control complexity |
| Required reusability | Low (0.95) to Extra high (1.24) | Effort to build components others will reuse |
| Team continuity | Very high (0.81) to Very low (1.29) | Impact of turnover |
| Domain experience | Very high (0.81) to Very low (1.22) | Familiarity with this kind of application |

Levels above nominal (1.00) increase effort; levels below decrease it.

---

## Maintenance and TCO

Expand **Maintenance and TCO** in the sidebar:

- **Annual maintenance rate**: share of the build cost spent on maintenance each year (default 20%)
- **Maintenance years**: years to project (default 3; set 0 to show the build cost only)

Maintenance escalates 5% a year. The total cost of ownership is the build cost plus maintenance in today's dollars (discounted at 5% a year); the nominal total is shown beside it.

---

## Understanding the result

### The headline block

The estimated cost with its range on a scale from $0, a status line (*Within plan*, *Compressed schedule*, *Not feasible with this team cap*), three tiles (schedule, team, total cost of ownership or effort) each with its reference and basis, and a scope line listing what the number is based on.

### What plan should I choose?

A planner directly under the headline block. Three optional facts (people available 1 to 8, deadline 1 to 60 months, budget in USD) drive up to five plan cards: with your team, for your deadline, within your budget, cheapest, fastest practical. Each card shows cost, months, FTE, the caps that produce it, a status word and the rush premium, with **Apply** (sets the sidebar caps; Undo offered) and **Save as scenario**. A staffing curve shows the fastest practical months and the natural schedule for one to eight people, the 75% practical floor, and where coordination overhead starts (six people). Unmet deadlines and budgets are explained: nearest achievable date and team, or the share of scope that would fit and the reuse or tooling change that would save the difference. The plan page of the PDF carries the same table, curve and advice. Planner facts travel in share links.

### Sections

- **How is the cost built?** Waterfall from base effort through each factor to the final figure; labelled; sums exactly to the estimate.
- **What if the deadline moves?** Cost at each schedule cap from 3 to 60 months; your cap is the diamond; shaded caps carry a compression premium; hollow points exceed your team cap.
- **Which choices matter most?** The waterfall's factors ranked by dollars.
- **What is the code made of?** Lines by language; grey bars are not billed.
- **How sensitive is the estimate?** Cost across team experience and complexity.
- **What does it cost to keep running?** Build, maintenance (nominal and today's dollars), total cost of ownership, and ownership cost at other maintenance rates.
- **Assumptions and data** Every input and result, plus a plain-text report.

Each chart card can be expanded to full screen. When the headline block scrolls out of view, a summary strip at the bottom keeps the cost, schedule and a PDF button in reach.

---

## Scenarios

**Save as scenario** under the headline pins the current estimate (inputs, language mix, advanced drivers and maintenance settings) to the **Scenarios** page. Up to three. Each scenario's inputs can be edited in place; a single developer-year cost is shared so the dollars stay comparable. The page shows aligned charts (cost with range, schedule, team) and a side-by-side table with the cost difference against Scenario 1.

---

## Sharing and export

Under the headline block:

- **Download PDF report**: a client-ready PDF with the headline estimate, charts, assumptions, cost steps and methodology.
- **Copy link**: the address bar always holds a link that reopens the exact estimate (repository scans are shared as their line counts).
- **CSV**: language table, cost steps and results.
- **JSON**: inputs, estimate and cost steps for programmatic use.

---

## Accessibility

The app works with a keyboard alone (a *Skip to main content* link is the first tab stop), respects reduced-motion settings, offers light and dark modes, and never signals status by colour alone.
