# PDF report pipeline smoke test. Skipped when Quarto or ggplot2 is missing
# (e.g. minimal CI runners) - the app degrades gracefully in that case too.

test_that("PDF report renders end to end", {
  skip_if_not_installed("quarto")
  skip_if_not_installed("ggplot2")
  skip_if(is.null(quarto::quarto_path()), "Quarto CLI not available")

  root <- if (dir.exists("R")) "." else file.path("..", "..")
  app_dir <- file.path(root, "cost-estimator-app")
  source(file.path(app_dir, "modules", "theme.R"), local = FALSE)
  source(file.path(app_dir, "modules", "app_helpers.R"), local = FALSE)
  source(file.path(app_dir, "modules", "ui_helpers.R"), local = FALSE)
  source(file.path(app_dir, "modules", "pdf_report.R"), local = FALSE)
  source(file.path(app_dir, "modules", "analysis_module.R"), local = FALSE)
  source(file.path(app_dir, "modules", "plan_helpers.R"), local = FALSE)

  e <- estimate_shiny_cost(20000, maintenance_rate = 0.20, maintenance_years = 3)
  curve <- data.frame(schedule = seq(3, 60, 1))
  curve$cost <- sapply(curve$schedule, function(s)
    estimate_shiny_cost(20000, max_schedule_months = s)$cost_usd)
  curve$feasible <- sapply(curve$schedule, function(s)
    estimate_shiny_cost(20000, max_schedule_months = s)$schedule_feasible)

  bd <- list(total_code = 20000, billable_code = 20000, has_docs = FALSE, language_mix = list(R = 20000))
  payload <- build_report_payload(
    est = e,
    billable = bd,
    curve = curve,
    project_name = "Test Project",
    plan = plan_advice(bd, PARAM_DEFAULTS, list(people = 2, months = 6))
  )
  expect_false(is.null(payload$plan$plans$team))
  expect_null(payload$plan$plans$team$est)   # slimmed for the report

  out <- tempfile(fileext = ".pdf")
  old_wd <- setwd(app_dir); on.exit(setwd(old_wd))
  render_estimate_pdf(payload, out)
  setwd(old_wd)

  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 10000)
})

test_that("module server computes a consistent estimate (testServer smoke)", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("plotly")
  skip_if_not_installed("DT")

  # "built under R version x" warnings come from the local install, not the app
  suppressWarnings(suppressPackageStartupMessages({
    library(shiny); library(bslib); library(plotly); library(DT)
  }))

  root <- if (dir.exists("R")) "." else file.path("..", "..")
  app_dir <- file.path(root, "cost-estimator-app")
  source(file.path(app_dir, "modules", "theme.R"), local = FALSE)
  source(file.path(app_dir, "modules", "app_helpers.R"), local = FALSE)
  source(file.path(app_dir, "modules", "ui_helpers.R"), local = FALSE)
  source(file.path(app_dir, "modules", "pdf_report.R"), local = FALSE)
  source(file.path(app_dir, "modules", "analysis_module.R"), local = FALSE)
  source(file.path(app_dir, "modules", "plan_helpers.R"), local = FALSE)

  shiny::testServer(
    analysisResultsServer,
    args = list(
      analysis_data = reactive(list(language_mix = list(R = 10000),
                                    source_label = "Manual Entry")),
      params = reactive(list(complexity = "medium", team_exp = 4,
                             reuse = 1.0, tools = 1.0, wage = 105000,
                             max_team = 5, max_schedule = 24)),
      mode = reactive("light")
    ),
    {
      e <- est()
      expect_gt(e$cost_usd, 0)
      # The displayed identity must hold
      expect_equal(e$effort_person_months,
                   e$final_people * e$final_schedule_months,
                   tolerance = 0.05)
      curve <- tradeoff_curve()
      expect_true(all(diff(curve$cost) <= 1))  # cost non-increasing in schedule
      expect_true(all(c("schedule", "cost", "feasible") %in% names(curve)))
      # One decomposition feeds the waterfall, the ranked bars and the PDF:
      # it must total exactly to the headline figure
      s <- steps()
      expect_equal(sum(s$delta[s$kind != "total"]), e$cost_usd, tolerance = 1e-9)
      expect_equal(s$delta[s$kind == "total"], e$cost_usd)
      snap <- snapshot()
      expect_equal(snap$language_mix, list(R = 10000))
      expect_equal(snap$params$max_schedule, 24)
      # Plan advisor: facts flow in, Apply hands back the plan's exact caps
      session$setInputs(know_people = 3, know_months = 40, know_budget = 5e6)
      a <- advice()
      expect_equal(a$know$people, 3)
      expect_true(length(a$narrative) >= 3)
      expect_false(is.null(a$recommendations$plans$cheapest))
      ret <- session$getReturned()
      session$setInputs(apply_cheapest = 1)
      ap <- ret$apply_plan()
      expect_equal(ap$max_team, a$recommendations$plans$cheapest$k)
      expect_equal(ap$max_schedule, a$recommendations$plans$cheapest$cap)
      session$setInputs(save_team = 1)
      sv <- ret$save_plan()
      expect_equal(sv$params$max_team, 3)
      expect_equal(sv$est$final_people <= 3 + 1e-9, TRUE)
    }
  )
})
