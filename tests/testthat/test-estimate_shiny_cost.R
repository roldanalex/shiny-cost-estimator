# Tests for estimate_shiny_cost()
# Functions should already be sourced before running tests

test_that("return structure has expected fields", {
  result <- estimate_shiny_cost(10000)
  expect_type(result, "list")
  expect_true("code_lines" %in% names(result))
  expect_true("effort_person_months" %in% names(result))
  expect_true("schedule_months" %in% names(result))
  expect_true("cost_usd" %in% names(result))
  expect_true("final_people" %in% names(result))
  expect_true("final_schedule_months" %in% names(result))
  expect_true("compression_penalty" %in% names(result))
  expect_true("coordination_premium" %in% names(result))
  expect_true("schedule_feasible" %in% names(result))
  expect_true("average_monthly_cost" %in% names(result))
  expect_true("estimate_range" %in% names(result))
  expect_true("multiplier_breakdown" %in% names(result))
  expect_true("params" %in% names(result))
  # Deprecated aliases kept for one release
  expect_equal(result$realistic_cost_usd, result$cost_usd)
  expect_equal(result$premium_multiplier, result$compression_penalty)
  expect_equal(result$confidence_interval, result$estimate_range)
})

test_that("known input produces reasonable ranges", {
  result <- estimate_shiny_cost(10000, complexity = "medium", team_experience = 4)
  expect_gt(result$cost_usd, 0)
  expect_gt(result$effort_person_months, 0)
  expect_gt(result$final_schedule_months, 0)
  expect_gt(result$final_people, 0)
  expect_equal(result$code_lines, 10000)
})

test_that("complexity ordering: low < medium < high", {
  low <- estimate_shiny_cost(10000, complexity = "low")
  med <- estimate_shiny_cost(10000, complexity = "medium")
  high <- estimate_shiny_cost(10000, complexity = "high")
  expect_lt(low$effort_person_months, med$effort_person_months)
  expect_lt(med$effort_person_months, high$effort_person_months)
})

test_that("team experience reduces cost", {
  novice <- estimate_shiny_cost(10000, team_experience = 1)
  expert <- estimate_shiny_cost(10000, team_experience = 5)
  expect_gt(novice$cost_usd, expert$cost_usd)
})

test_that("input validation rejects bad inputs", {
  expect_error(estimate_shiny_cost(-100))
  expect_error(estimate_shiny_cost(10000, complexity = "invalid"))
  expect_error(estimate_shiny_cost(10000, team_experience = 0))
  expect_error(estimate_shiny_cost(10000, team_experience = 6))
  expect_error(estimate_shiny_cost(10000, reuse_factor = 0.5))
  expect_error(estimate_shiny_cost(10000, reuse_factor = 1.5))
  expect_error(estimate_shiny_cost(10000, tool_support = 0.5))
  expect_error(estimate_shiny_cost(10000, tool_support = 1.5))
  expect_error(estimate_shiny_cost(10000, rely = 0.5))
  expect_error(estimate_shiny_cost(10000, cplx = 2.0))
  expect_error(estimate_shiny_cost(10000, ruse = 0.5))
  expect_error(estimate_shiny_cost(10000, pcon = 0.5))
  expect_error(estimate_shiny_cost(10000, apex = 0.5))
  # Financial parameters (previously unvalidated)
  expect_error(estimate_shiny_cost(10000, avg_wage = -105000))
  expect_error(estimate_shiny_cost(10000, avg_wage = 0))
  expect_error(estimate_shiny_cost(10000, avg_wage = NA_real_))
  expect_error(estimate_shiny_cost(10000, max_team_size = 0))
  expect_error(estimate_shiny_cost(10000, max_schedule_months = 0))
  expect_error(estimate_shiny_cost(10000, max_schedule_months = -6))
  expect_error(estimate_shiny_cost(10000, discount_rate = -0.01))
  expect_error(estimate_shiny_cost(10000, discount_rate = 0.30))
})

test_that("zero code lines returns zero cost", {
  result <- estimate_shiny_cost(0)
  expect_equal(result$cost_usd, 0)
  expect_equal(result$effort_person_months, 0)
  expect_equal(result$final_people, 0)
  expect_equal(result$final_schedule_months, 0)
  expect_true(result$schedule_feasible)
})

test_that("estimate range brackets cost at +/-30%", {
  result <- estimate_shiny_cost(10000)
  expect_lt(result$estimate_range$low, result$cost_usd)
  expect_gt(result$estimate_range$high, result$cost_usd)
  expect_equal(result$estimate_range$low, round(result$cost_usd * 0.70), tolerance = 1)
  expect_equal(result$estimate_range$high, round(result$cost_usd * 1.30), tolerance = 1)
})

test_that("maintenance calculation works correctly", {
  result <- estimate_shiny_cost(10000, maintenance_years = 3, maintenance_rate = 0.20)
  expect_false(is.null(result$maintenance))
  expect_equal(result$maintenance$maintenance_years, 3)
  expect_equal(result$maintenance$maintenance_rate, 0.20)
  expect_equal(length(result$maintenance$yearly_costs), 3)
  # TCO = build + PV of maintenance (tolerance for rounding)
  expect_equal(result$maintenance$tco,
               result$cost_usd + result$maintenance$total_maintenance_pv,
               tolerance = 2)
  # Year 2 should be more than year 1 (5% annual escalation)
  expect_gt(result$maintenance$yearly_costs[2], result$maintenance$yearly_costs[1])
})

test_that("maintenance PV is discounted below nominal", {
  result <- estimate_shiny_cost(10000, maintenance_years = 5, maintenance_rate = 0.20,
                                discount_rate = 0.05)
  expect_lt(result$maintenance$total_maintenance_pv,
            result$maintenance$total_maintenance_nominal)
  no_discount <- estimate_shiny_cost(10000, maintenance_years = 5, maintenance_rate = 0.20,
                                     discount_rate = 0)
  expect_equal(no_discount$maintenance$total_maintenance_pv,
               no_discount$maintenance$total_maintenance_nominal)
})

test_that("maintenance is NULL when years = 0", {
  result <- estimate_shiny_cost(10000, maintenance_years = 0)
  expect_null(result$maintenance)
})

test_that("constraint premiums apply for large projects", {
  result <- estimate_shiny_cost(100000, max_schedule_months = 6, max_team_size = 3)
  expect_gt(result$compression_penalty, 1.0)
  unconstrained <- estimate_shiny_cost(100000, max_schedule_months = 240, max_team_size = 3)
  expect_gt(result$cost_usd / result$final_schedule_months,
            unconstrained$cost_usd / unconstrained$final_schedule_months)
  # An 18x compression is not feasible with the capped team - flag must fire
  expect_false(result$schedule_feasible)
})

test_that("COCOMO II drivers affect cost", {
  base <- estimate_shiny_cost(10000)
  high_rely <- estimate_shiny_cost(10000, rely = 1.26)
  expect_gt(high_rely$effort_person_months, base$effort_person_months)

  high_cplx <- estimate_shiny_cost(10000, cplx = 1.74)
  expect_gt(high_cplx$effort_person_months, base$effort_person_months)
})

test_that("multiplier breakdown is consistent", {
  result <- estimate_shiny_cost(10000)
  mb <- result$multiplier_breakdown
  expected_total <- mb$EM_experience * mb$EM_reuse * mb$EM_tools * mb$EM_modern *
                    mb$EM_rely * mb$EM_cplx * mb$EM_ruse * mb$EM_pcon * mb$EM_apex
  expect_equal(mb$EM_total, expected_total, tolerance = 1e-10)
})

test_that("language mix affects KLOC weighting", {
  py_result <- estimate_shiny_cost(10000, language_mix = list("Python" = 10000))
  js_result <- estimate_shiny_cost(10000, language_mix = list("JavaScript" = 10000))
  # JavaScript (0.9 productivity) should cost more than Python (1.1 productivity)
  expect_gt(js_result$effort_person_months, py_result$effort_person_months)
})

test_that("params are preserved in output", {
  result <- estimate_shiny_cost(5000, complexity = "high", team_experience = 2,
                                reuse_factor = 1.1, tool_support = 0.9)
  expect_equal(result$params$complexity, "high")
  expect_equal(result$params$team_experience, 2)
  expect_equal(result$params$reuse_factor, 1.1)
  expect_equal(result$params$tool_support, 0.9)
  expect_equal(result$params$discount_rate, 0.05)
})

# ---- Any software project: framework calibration and language table ----------

test_that("framework = 'systems' removes exactly the 0.85 modern-framework discount", {
  m <- estimate_shiny_cost(20000)
  s <- estimate_shiny_cost(20000, framework = "systems")
  expect_equal(m$multiplier_breakdown$EM_modern, 0.85)
  expect_equal(s$multiplier_breakdown$EM_modern, 1.0)
  expect_equal(s$unconstrained_effort_pm / m$unconstrained_effort_pm, 1 / 0.85, tolerance = 1e-3)
  expect_equal(m$params$framework, "modern")
  expect_equal(s$params$framework, "systems")
  expect_error(estimate_shiny_cost(1000, framework = "quantum"))
})

test_that("language productivity table covers the supported stacks and unknowns count at 1.0", {
  expect_equal(unname(LANGUAGE_PRODUCTIVITY["R"]), 1.0)
  expect_equal(unname(LANGUAGE_PRODUCTIVITY["TypeScript"]), unname(LANGUAGE_PRODUCTIVITY["JavaScript"]))
  expect_equal(unname(LANGUAGE_PRODUCTIVITY["Ruby"]), unname(LANGUAGE_PRODUCTIVITY["Python"]))
  for (l in c("Go", "Rust", "C#", "Kotlin", "Swift", "Scala", "Java", "C", "C++"))
    expect_equal(unname(LANGUAGE_PRODUCTIVITY[l]), 1.0, info = l)
  expect_true(all(LANGUAGE_PRODUCTIVITY > 0.5 & LANGUAGE_PRODUCTIVITY < 1.5))
  # an unlisted language is priced like R, never dropped
  expect_equal(estimate_shiny_cost(5000, language_mix = list(Zig = 5000))$cost_usd,
               estimate_shiny_cost(5000, language_mix = list(R = 5000))$cost_usd)
  # a higher-productivity language is cheaper for the same line count
  expect_lt(estimate_shiny_cost(5000, language_mix = list(SQL = 5000))$cost_usd,
            estimate_shiny_cost(5000, language_mix = list(R = 5000))$cost_usd)
})
