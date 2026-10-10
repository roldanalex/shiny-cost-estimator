# Getting Started: Shiny Cost Estimator (v2.2.0)

A five-minute path from clone to first estimate. For full documentation see
[README.md](README.md); for hosting see [DEPLOYMENT.md](DEPLOYMENT.md).

## 1. Install dependencies

```r
install.packages(c("shiny", "bslib", "plotly", "DT", "markdown", "jsonlite",
                   "quarto", "ggplot2", "knitr", "ragg"))
```

For PDF reports, also install the [Quarto CLI](https://quarto.org/docs/get-started/)
(version 1.3 or later; Typst is bundled, no LaTeX or Chrome needed).

Verify everything:

```r
source("cost-estimator-app/check_dependencies.R")
```

## 2. Run the app

```r
# From the repository root
shiny::runApp("cost-estimator-app")
```

## 3. Your first estimate

The first screen shows a worked example. Choose **Run this example** to see a
complete estimate, or:

1. Under **Where is the code?** keep **Manual** and type line counts
   (for example R: 15000, JavaScript: 3000, CSS: 2000).
2. Set **Complexity**, **Team experience** and **Cost per developer-year**.
   Every input has a `?` popover explaining what it means.
3. Choose **Run estimate**.

You get the headline cost with its ±30% range, a status line, schedule and
team tiles, and sections that answer one question each (how the cost is built,
what happens if the deadline moves, which choices matter most, what it costs
to keep running). Line counts and uploads need *Run estimate*; every other
input recalculates live.

## 4. Let the planner choose

Under the headline, **What plan should I choose?** turns what you know into plans. Type the
people you have, a deadline, or a budget (or nothing) and choose **Apply** on a card to make
it the headline estimate.

## 5. Analyse a real repository

- **ZIP**: works everywhere, max 50 MB.
- **Folder** (local runs only): point at any project directory.

Documentation and config files (Markdown, JSON, YAML, …) are counted and shown
but **excluded from the billable estimate**.

## 6. Compare what-ifs

Choose **Save as scenario** under the headline, change something (a shorter
deadline, a smaller team), save again, and open **Scenarios**. Each one is
editable in place and the comparison updates as you type.

## 7. Share the result

- **Download PDF report**: a client-ready PDF (cover, charts, assumptions,
  cost steps, methodology).
- **Copy link**: the address bar always reopens the exact estimate.
- **CSV / JSON**: data downloads.

## 8. Deploy

```bash
Rscript tools/deploy.R   # syncs engine copies, deploys to shinyapps.io
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for shinyapps.io setup, the Quarto/Typst
PDF notes, and other hosting options.
