This app answers one question: **what would it cost to build (or rebuild) a software application?** Describe the project, or let the app count its code, and you get the development cost, timeline, team size and total cost of ownership, with a PDF you can forward.

No technical background is needed. Every input has a **?** next to it with a plain-language explanation.

---

## The two pages

| Page | Use it to... |
|---|---|
| **Estimate** | Produce an estimate for one project (start here) |
| **Scenarios** | Pin up to three what-if versions of an estimate side by side |

The **Help** menu in the top bar opens this guide, the parameter reference and the release notes. The sun/moon button switches between light and dark mode.

---

## Your first estimate (2 minutes)

1. On the **Estimate** page, keep **Manual** selected under *Where is the code?*
2. Enter roughly how many lines of code the project has, split by language (for example R: 15,000, JavaScript: 3,000). A rough guess is fine; you can refine later.
3. Set the three inputs that matter most:
   - **Complexity**: how architecturally involved the app is (when in doubt, Medium)
   - **Team experience**: average skill of the team, 1 (novice) to 5 (expert)
   - **Cost per developer-year**: the fully loaded yearly cost of one developer
4. Choose **Run estimate**.

Or choose **Run this example** on the first screen to see a worked estimate immediately.

> **Live recalculation.** Line counts and uploads need *Run estimate*. Every other input (complexity, experience, reuse, caps, maintenance) updates the estimate the moment you change it. The note under the headline figure reminds you of this.

### Don't know your line counts?

Let the app count them:

- **ZIP**: zip the project folder and upload it (up to 50 MB). Files are counted on the server and discarded.
- **Folder** (only when the app runs on your own computer): point it at the project directory.

Languages are detected automatically. Documentation and configuration files (README files, JSON, YAML, …) are shown in the results but **never counted toward the cost**. Only real code is billed.

### Reset and undo

**Reset** returns every parameter to its default. A toast offers **Undo** for 15 seconds if you change your mind.

---

## Reading the result

### The headline block

- **Estimated development cost**, with its **estimate range (±30%)** drawn on a scale that starts at $0, so you can see how wide the uncertainty is.
- A **status line**: *Within plan*, *Compressed schedule* (with the premium) or *Not feasible with this team cap*.
- Three tiles: **Schedule** (against your cap and the natural schedule), **Team** (in full-time equivalents, against your cap) and **Total cost of ownership** (or effort when maintenance is off).
- A **scope line** listing exactly what the number is based on.

Under the block: **Download PDF report**, **Save as scenario**, **Copy link** (the address bar always holds a link that reopens this exact estimate), and **CSV / JSON** downloads.

### What plan should I choose?

The first section under the headline is a planner. Tell it what you already know, all optional:

- **People available**: the fastest realistic delivery with that team, and what one more or one fewer person changes.
- **Deadline (months)**: the smallest team that meets it and the rush premium it carries, or, if it cannot be met with up to eight people, the nearest achievable date.
- **Budget (USD)**: whether the cheapest plan fits and the fastest plan within budget; if nothing fits, how much of the scope would, and which input (code reuse, tooling) would close the gap.

With nothing filled in it still shows the **cheapest** plan, the **fastest practical** one, and a **staffing curve** (months to deliver for one to eight people, cost on each point). Every card has **Apply**, which sets the team and schedule caps in the sidebar so the headline becomes that plan, and **Save as scenario**. Plans shorter than 75% of the natural schedule are shown on the curve but never recommended: that is the limit COCOMO II treats as practical.

### The sections

Each section is named for the question it answers. The first two are open; click a heading to open the rest.

- **How is the cost built?** A waterfall from base effort through every factor to the final figure. The bars sum exactly to the estimate; each is labelled.
- **What if the deadline moves?** Cost at every schedule cap. The diamond is your cap. Shaded caps are shorter than the natural schedule and carry a compression premium; hollow points would need more people than your team cap allows.
- **Which choices matter most?** The same factors as the waterfall, ranked by dollars. Bars to the left save money, bars to the right add cost.
- **What is the code made of?** Lines by language. Grey bars are documentation and configuration, which are never billed.
- **How sensitive is the estimate?** Cost across team experience and complexity, everything else held at your values. The diamond is your estimate.
- **What does it cost to keep running?** Build cost, maintenance over the years you chose (nominal and in today's dollars) and the total cost of ownership, with a chart of ownership cost at other maintenance rates.
- **Assumptions and data** Every input behind the number, and a plain-text report you can paste anywhere.

---

## What the numbers mean (honest fine print)

- **Estimate range (±30%)**: software estimation is uncertain. The range reflects the typical accuracy of this class of model (COCOMO II); treat the low and high ends as equally plausible. Figures are rounded for display.
- **Schedule warnings**: if you cap the schedule tighter than the work naturally allows, the app adds a compression premium (rush work costs more) and says so. If the deadline would need more people than your team cap allows, it flags the plan as **not feasible** rather than pretending.
- **Consistency**: effort = team size × schedule, the waterfall totals the headline cost, the ranked drivers use the same numbers as the waterfall, and the PDF shows the same figures as the screen.

---

## Scenarios

1. Get an estimate you like on the **Estimate** page and choose **Save as scenario**.
2. Change something (a shorter deadline, a smaller team, higher complexity) and save again. Up to three.
3. On the **Scenarios** page, every saved scenario has its own cost, schedule, team and status, and an **Inputs** panel you can edit; the comparison updates as you type. One developer-year cost is shared by all scenarios so the dollars stay comparable.

The chart puts cost (with its range), schedule and team on the same scales, and the table lists every input and result, with the cost difference against Scenario 1.

---

## Sharing your estimate

- **PDF report**: a multi-page document with the headline estimate, charts, every assumption, how the cost is built and a methodology page. Ready to email. Takes a few seconds; the progress shows elapsed time.
- **Copy link**: the address bar always describes the current estimate. Anyone who opens the link sees the same number. Repository scans are shared as their line counts.
- **CSV / JSON**: the language table, the cost steps and the results, for spreadsheets or other tools.

---

## Frequently asked questions

**Why did the cost jump when I shortened the schedule?**
Compressed timelines need more parallel work, senior talent and overtime. The model adds a premium that grows with the amount of compression (up to double the cost).

**Why is the team size shown as 2.4 FTE?**
It is an average staffing level over the project: roughly two full-time developers plus one part-time.

**Why doesn't adding documentation increase the estimate?**
Only code that must be designed, written and tested drives cost. Docs and config files are listed for transparency but excluded from billing.

**Which cost per developer-year should I enter?**
The *fully loaded* annual cost: salary plus benefits and overhead. If you only know base salary, add roughly 25 to 40%.

**Can I trust a single number?**
Use the range, not the point estimate, for budgeting, and read the methodology page of the PDF report for exactly how the numbers are produced.
