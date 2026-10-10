# Plan advisor contracts: every recommendation is an exact engine call, the
# practical floor is respected, and the narrative states the computed figures.

local({
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  app <- file.path(root, "cost-estimator-app", "modules")
  source(file.path(app, "app_helpers.R"), local = FALSE)
  source(file.path(app, "ui_helpers.R"), local = FALSE)
  source(file.path(app, "analysis_module.R"), local = FALSE)   # run_estimate(), split_billable()
  source(file.path(app, "plan_helpers.R"), local = FALSE)
})

bd60 <- list(billable_code = 60000, language_mix = list(R = 45000, SQL = 9000, JavaScript = 6000),
             total_code = 60000, has_docs = FALSE)
p0 <- PARAM_DEFAULTS

test_that("plan_grid prices every team size, dedupes natural plans, and flags the floor", {
  pg <- plan_grid(bd60, p0)
  expect_false(pg$zero)
  expect_setequal(unique(pg$grid$k), 1:8)
  expect_equal(pg$floor_months, max(1, 0.75 * pg$nominal_months))
  # one uncompressed (natural) plan per team size, priced with no cap
  expect_equal(sum(pg$grid$uncompressed), 8)
  expect_true(all(pg$grid$premium[pg$grid$uncompressed] <= 1))
  expect_true(all(pg$grid$months[pg$grid$practical] >= pg$floor_months - 1e-9))
  # more team never lengthens the natural schedule
  nat <- pg$grid[pg$grid$uncompressed, ]
  nat <- nat[order(nat$k), ]
  expect_true(all(diff(nat$months) <= 1e-9))
})

test_that("cheapest plan is uncompressed and every plan reproduces through the engine", {
  pg  <- plan_grid(bd60, p0)
  rec <- recommend_plans(pg, bd60, p0, list(people = 3, months = 12, budget = 900000))
  ch <- rec$plans$cheapest
  expect_true(ch$premium <= 1)
  expect_equal(ch$cost, min(pg$grid$cost[pg$grid$feasible & pg$grid$practical]))
  for (pl in rec$plans) {
    e <- run_estimate(bd60, p0, overrides = list(max_team_size = pl$k, max_schedule_months = pl$cap,
                                                 maintenance_rate = 0, maintenance_years = 0))
    expect_equal(e$cost_usd, pl$cost, info = pl$key)
    expect_equal(e$final_schedule_months, pl$months, info = pl$key)
    expect_true(pl$feasible, info = pl$key)
    expect_true(pl$months >= pg$floor_months - 1e-9, info = pl$key)
  }
})

test_that("fastest practical is the minimum over practical plans and the curve is monotone", {
  pg  <- plan_grid(bd60, p0)
  rec <- recommend_plans(pg, bd60, p0)
  ok <- pg$grid[pg$grid$feasible & pg$grid$practical, ]
  f <- if (!is.null(rec$plans$fastest)) rec$plans$fastest else rec$plans$cheapest
  expect_equal(f$months, min(ok$months))
  cv <- staffing_curve(pg)
  expect_equal(nrow(cv), 8)
  m <- cv$months[!is.na(cv$months)]
  expect_true(all(diff(m) <= 1e-9))   # more people, never slower
  expect_true(all(diff(cv$natural_months) <= 1e-9))
  expect_false(any(is.na(cv$natural_months)))
})

test_that("team card carries the deltas for one more and one fewer person", {
  pg  <- plan_grid(bd60, p0)
  rec <- recommend_plans(pg, bd60, p0, list(people = 3))
  t <- rec$plans$team
  expect_equal(t$k, 3L)
  expect_false(is.null(t$delta_up)); expect_false(is.null(t$delta_down))
  expect_true(t$delta_up$months_saved >= 0)
  expect_true(t$delta_down$months_added >= 0)
  rec1 <- recommend_plans(pg, bd60, p0, list(people = 1))
  expect_null(rec1$plans$team$delta_down)
  rec8 <- recommend_plans(pg, bd60, p0, list(people = 8))
  expect_null(rec8$plans$team$delta_up)
})

test_that("deadline card finds the smallest feasible team, or says it cannot be met", {
  pg  <- plan_grid(bd60, p0)
  ok <- pg$grid[pg$grid$feasible & pg$grid$practical, ]
  d <- ceiling(min(ok$months)) + 2      # an achievable deadline for this project
  rec <- recommend_plans(pg, bd60, p0, list(months = d))
  expect_true(rec$plans$deadline$achievable)
  expect_true(rec$plans$deadline$months <= d + 1e-9)
  expect_equal(rec$plans$deadline$k, min(ok$k[ok$months <= d + 1e-9]))
  # below the floor: unmet, with the nearest practical plan attached
  rec2 <- recommend_plans(pg, bd60, p0, list(months = 3))
  expect_null(rec2$plans$deadline)
  expect_false(is.null(rec2$unmet$deadline))
  expect_equal(rec2$unmet$deadline$nearest$months, min(ok$months))
})

test_that("budget card fits or explains what would", {
  pg  <- plan_grid(bd60, p0)
  rec <- recommend_plans(pg, bd60, p0)
  cheapest <- rec$plans$cheapest$cost
  big <- recommend_plans(pg, bd60, p0, list(budget = cheapest * 1.5))
  expect_true(big$plans$budget$fits)
  expect_true(big$plans$budget$cost <= cheapest * 1.5)
  small <- recommend_plans(pg, bd60, p0, list(budget = cheapest * 0.5))
  expect_null(small$plans$budget)
  u <- small$unmet$budget
  expect_true(u$scope$share > 0 && u$scope$share < 1)
  expect_true(u$scope$cost <= cheapest * 0.5)
  # the scope that fits really re-estimates within budget
  mix <- lapply(bd60$language_mix, function(v) v * u$scope$share)
  e <- run_estimate(list(billable_code = sum(unlist(mix)), language_mix = mix), p0,
                    overrides = list(max_team_size = 8, max_schedule_months = 36, maintenance_years = 0))
  expect_true(e$cost_usd <= cheapest * 0.5 * 1.01)
  expect_true(length(u$levers) >= 1)
  expect_true(all(vapply(u$levers, function(l) l$saving > 0, logical(1))))
})

test_that("narrative states the figures and ends with the range caveat", {
  pg  <- plan_grid(bd60, p0)
  rec <- recommend_plans(pg, bd60, p0, list(people = 3, months = 3, budget = 100000))
  txt <- plan_narrative(rec, pg, list(people = 3, months = 3, budget = 100000))
  expect_match(txt[1], "^With 3 people")
  expect_true(any(grepl("not achievable", txt)))
  expect_true(any(grepl("No plan fits", txt)))
  expect_true(any(grepl(fmt_usd(rec$plans$cheapest$cost), txt, fixed = TRUE)))
  expect_equal(tail(txt, 1), "Budget on the range, not the figure.")
})

test_that("degenerate inputs do not error", {
  z <- plan_advice(list(billable_code = 0, language_mix = list(), total_code = 0, has_docs = FALSE), p0)
  expect_true(z$grid$zero)
  expect_match(z$narrative[1], "Nothing to plan")
  tiny <- plan_advice(list(billable_code = 400, language_mix = list(R = 400), total_code = 400, has_docs = FALSE), p0,
                      list(people = 4))
  expect_true(tiny$grid$nominal_people < 1)
  expect_true(any(grepl("one-person project", tiny$narrative)))
  expect_false(is.null(tiny$recommendations$plans$cheapest))
})
