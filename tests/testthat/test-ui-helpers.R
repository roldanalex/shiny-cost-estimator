# Contract tests for the pure UI builders (htmltools tags, no session)

local({
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  source(file.path(root, "cost-estimator-app", "modules", "app_helpers.R"), local = FALSE)
  source(file.path(root, "cost-estimator-app", "modules", "ui_helpers.R"), local = FALSE)
})

html <- function(x) as.character(htmltools::renderTags(x)$html)

test_that("kpi_tile refuses a bare number and carries its hooks", {
  expect_error(kpi_tile("Cost", "$1"), "reference")
  expect_error(kpi_tile("Cost", "$1", reference = "Cap"), "n_text")
  h <- html(kpi_tile("Schedule", "12 months", reference = "Cap 24 months",
                     n_text = "Natural 9.8 months", status = "watch", status_label = "Compressed"))
  expect_match(h, 'data-ux="kpi"')
  expect_match(h, 'data-status="watch"')
  expect_match(h, "Cap 24 months")
  expect_match(h, "Natural 9.8 months")
  expect_match(h, "Compressed")              # status is a word, never colour alone
  expect_match(h, 'aria-hidden="true"')      # icon is decorative
})

test_that("state_panel needs a reason and uses role=alert only for errors", {
  expect_error(state_panel("empty", "Nothing"), "why")
  h <- html(state_panel("empty", "No estimate yet", "Run one first."))
  expect_match(h, 'data-kind="empty"'); expect_match(h, 'role="status"')
  h2 <- html(state_panel("error", "Could not scan", "The archive was unreadable."))
  expect_match(h2, 'role="alert"')
})

test_that("question_section renders a details/summary with the question", {
  h <- html(question_section("How is the cost built?", "One factor at a time", open = TRUE, "body"))
  expect_match(h, "<details")
  expect_match(h, "open")
  expect_match(h, "One factor at a time")
})

test_that("field_with_help gives the input a real label and an accessible help trigger", {
  h <- html(field_with_help(shiny::numericInput("wage", NULL, 1), label = "Wage", input_id = "wage",
                            help_title = "Wage", help_body = shiny::p("Explains the wage.")))
  expect_match(h, '<label class="field-label" for="wage">Wage</label>')
  expect_match(h, 'aria-label="About wage"')
  expect_match(h, 'id="wage_help"')
})

test_that("estimate_status gives one verdict for hero, strip and PDF", {
  ok <- estimate_status(estimate_shiny_cost(10000))
  expect_equal(ok$kind, "ok")
  comp <- estimate_status(estimate_shiny_cost(60000, max_schedule_months = 12, max_team_size = 8))
  expect_true(comp$kind %in% c("watch", "action"))
  bad <- estimate_status(estimate_shiny_cost(60000, max_schedule_months = 6, max_team_size = 3))
  expect_equal(bad$kind, "action")
  expect_match(bad$word, "Not feasible")
})

test_that("range_band scales from zero and describes itself", {
  h <- html(range_band(70000, 100000, 130000))
  expect_match(h, 'role="img"')
  expect_match(h, "\\$70,000 to \\$130,000, estimate \\$100,000")
  expect_match(h, "range-marker")
})

test_that("hero_estimate composes the contract pieces", {
  e  <- estimate_shiny_cost(10000, maintenance_years = 3)
  bd <- list(total_code = 10000, billable_code = 10000, language_mix = list(R = 10000), has_docs = FALSE)
  h  <- html(hero_estimate(e, bd, source_label = "Manual entry"))
  expect_match(h, 'data-ux="hero"')
  expect_match(h, 'aria-live="polite"')
  expect_match(h, 'data-ux="scope"')
  expect_equal(length(gregexpr('data-ux="kpi"', h)[[1]]), 3)
  expect_match(h, "Total cost of ownership")
  expect_match(h, "Source: Manual entry")
})
