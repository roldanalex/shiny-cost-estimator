# Unit tests for the pure app helpers (no Shiny session needed)

local({
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  source(file.path(root, "cost-estimator-app", "modules", "app_helpers.R"),
         local = FALSE)
})

test_that("clean_count sanitizes hostile inputs", {
  expect_equal(clean_count(100), 100)
  expect_equal(clean_count(0), 0)
  expect_equal(clean_count(NULL), 0)
  expect_equal(clean_count(NA), 0)
  expect_equal(clean_count(NA_real_), 0)
  expect_equal(clean_count(-50), 0)
  expect_equal(clean_count(Inf), 0)
  expect_equal(clean_count(NaN), 0)
  expect_equal(clean_count("abc"), 0)
  expect_equal(clean_count("123"), 123)
  expect_equal(clean_count(numeric(0)), 0)
  expect_equal(clean_count(c(1, 2)), 0)
})

test_that("build_language_mix drops blanks, NAs, and zeros", {
  mix <- build_language_mix(list(R = 5000, Python = NA, JavaScript = NULL,
                                 SQL = 0, CSS = -10, Other = "abc"))
  expect_equal(mix, list(R = 5000))
  expect_equal(build_language_mix(list(R = NA, Python = NULL)), setNames(list(), character(0)))
})

test_that("blank manual entry no longer crashes the engine", {
  # Regression: list(R = 100, Python = NA) used to produce an NA-named
  # element that crashed estimate_shiny_cost
  mix <- build_language_mix(list(R = 100, Python = NA))
  e <- estimate_shiny_cost(sum(unlist(mix)), language_mix = mix)
  expect_gt(e$cost_usd, 0)
})

test_that("parse_num_param bounds-checks URL values", {
  expect_equal(parse_num_param("1000"), 1000)
  expect_null(parse_num_param("abc"))
  expect_null(parse_num_param("-5"))
  expect_null(parse_num_param("99999999999"))
  expect_null(parse_num_param(NULL))
  expect_null(parse_num_param("Inf"))
  expect_equal(parse_num_param("3", lo = 1, hi = 5), 3)
  expect_null(parse_num_param("7", lo = 1, hi = 5))
})

# ---- Display formatting -------------------------------------------------------

test_that("fmt_usd rounds for display and never shows false precision", {
  expect_equal(fmt_usd(487213), "$487,000")
  expect_equal(fmt_usd(84567), "$84,600")
  expect_equal(fmt_usd(12345678), "$12,350,000")
  expect_equal(fmt_usd(105000, exact = TRUE), "$105,000")
  expect_equal(fmt_usd(-2500), "-$2,500")
  expect_equal(fmt_usd(NA_real_), NA_character_)
  expect_equal(fmt_usd(numeric(0)), character(0))
})

test_that("fmt_usd_short and the unit formatters read naturally", {
  expect_equal(fmt_usd_short(487213), "$487k")
  expect_equal(fmt_usd_short(1240000), "$1.24M")
  expect_equal(fmt_usd_short(850), "$850")
  expect_equal(fmt_months(12), "12 months")
  expect_equal(fmt_months(1), "1 month")
  expect_equal(fmt_months(9.53), "9.5 months")
  expect_equal(fmt_fte(3.21), "3.2 FTE")
  expect_equal(fmt_int(12400.4), "12,400")
})

# ---- Rating levels and defaults ----------------------------------------------

test_that("rating levels stay inside the engine's accepted bounds", {
  bounds <- list(reuse = c(0.7, 1.3), tools = c(0.8, 1.2), rely = c(0.82, 1.26),
                 cplx = c(0.73, 1.74), ruse = c(0.95, 1.24), pcon = c(0.81, 1.29),
                 apex = c(0.81, 1.22))
  for (k in names(bounds)) {
    lv <- RATING_LEVELS[[k]]$levels
    expect_true(all(lv >= bounds[[k]][1] & lv <= bounds[[k]][2]), info = k)
    expect_true(1.0 %in% lv, info = paste(k, "has a nominal level"))
    expect_equal(nearest_level(1.0, k), 1.0, info = k)
  }
  expect_equal(nearest_level(1.07, "reuse"), 1.0)
  expect_equal(nearest_level(0.72, "reuse"), 0.7)
  expect_equal(nearest_level("garbage", "rely"), PARAM_DEFAULTS$rely)
  expect_equal(team_exp_word(4), "Proficient")
  expect_equal(team_exp_word(9), "")
})

test_that("every default runs through the engine unchanged", {
  d <- PARAM_DEFAULTS
  e <- estimate_shiny_cost(10000, complexity = d$complexity, team_experience = d$team_exp,
                           reuse_factor = d$reuse, tool_support = d$tools, avg_wage = d$wage,
                           max_team_size = d$max_team, max_schedule_months = d$max_schedule,
                           rely = d$rely, cplx = d$cplx, ruse = d$ruse, pcon = d$pcon, apex = d$apex,
                           maintenance_rate = d$maintenance_rate,
                           maintenance_years = d$maintenance_years)
  expect_gt(e$cost_usd, 0)
  expect_false(is.null(e$maintenance))
})

# ---- Share link: every input that moves the number round-trips ---------------

test_that("share query reproduces the full estimate, not just four inputs", {
  params <- list(complexity = "high", team_exp = 3, reuse = 0.85, tools = 0.9,
                 wage = 120000, max_team = 6, max_schedule = 12, rely = 1.10,
                 cplx = 1.17, ruse = 1.07, pcon = 1.12, apex = 0.88,
                 maintenance_rate = 0.25, maintenance_years = 5)
  mix <- list(R = 12000, SQL = 800, Rust = 300)   # Rust folds into Other
  q <- build_share_query(params, mix)
  back <- parse_share_query(shiny::parseQueryString(paste0("?", q)))
  expect_equal(back$mix$R, 12000)
  expect_equal(back$mix$SQL, 800)
  expect_equal(back$mix$Other, 300)
  for (k in names(params)) expect_equal(back$params[[k]], params[[k]], info = k)

  # The two estimates must be identical to the dollar
  bd_in  <- list(billable_code = 13100, language_mix = mix_to_manual(mix))
  e_in   <- estimate_shiny_cost(13100, complexity = "high", team_experience = 3,
                                reuse_factor = 0.85, tool_support = 0.9, language_mix = bd_in$language_mix,
                                avg_wage = 120000, max_team_size = 6, max_schedule_months = 12,
                                rely = 1.10, cplx = 1.17, ruse = 1.07, pcon = 1.12, apex = 0.88,
                                maintenance_rate = 0.25, maintenance_years = 5)
  p <- back$params
  e_out <- estimate_shiny_cost(sum(unlist(back$mix)), complexity = p$complexity,
                               team_experience = p$team_exp, reuse_factor = p$reuse,
                               tool_support = p$tools, language_mix = Filter(function(x) x > 0, back$mix),
                               avg_wage = p$wage, max_team_size = p$max_team,
                               max_schedule_months = p$max_schedule, rely = p$rely, cplx = p$cplx,
                               ruse = p$ruse, pcon = p$pcon, apex = p$apex,
                               maintenance_rate = p$maintenance_rate,
                               maintenance_years = p$maintenance_years)
  expect_equal(e_out$cost_usd, e_in$cost_usd)
  expect_equal(e_out$maintenance$tco, e_in$maintenance$tco)
})

test_that("share query ignores hostile or out-of-range values", {
  q <- list(mode = "manual", r = "1e12", py = "-5", js = "abc", wage = "1",
            maxteam = "99", team = "7", reuse = "9", complexity = "ultra", myears = "40")
  back <- parse_share_query(q)
  expect_null(back$mix$R); expect_null(back$mix$Python); expect_null(back$mix$JavaScript)
  expect_null(back$params$wage); expect_null(back$params$max_team)
  expect_null(back$params$team_exp); expect_null(back$params$complexity)
  expect_null(back$params$maintenance_years)
  expect_null(back$params$reuse)   # 9 is outside the 0.5-2 window, so ignored
  expect_null(parse_share_query(list(mode = "zip", r = "100")))
})

# ---- One cost decomposition --------------------------------------------------

test_that("cost_steps totals exactly to the headline and lists the premiums", {
  e <- estimate_shiny_cost(60000, max_schedule_months = 6, max_team_size = 8, rely = 1.10)
  s <- cost_steps(e)
  expect_equal(sum(s$delta[s$kind != "total"]), e$cost_usd)
  expect_equal(s$delta[s$kind == "total"], e$cost_usd)
  expect_equal(tail(s$running, 1), e$cost_usd)
  expect_true("Schedule compression" %in% s$name)
  expect_true("Coordination overhead" %in% s$name)
  expect_true("Reliability" %in% s$name)
  expect_false("Product complexity" %in% s$name)   # nominal drivers are not shown
  expect_equal(s$kind[1], "base")

  e2 <- estimate_shiny_cost(10000)
  s2 <- cost_steps(e2)
  expect_equal(sum(s2$delta[s2$kind != "total"]), e2$cost_usd)
  expect_false(any(s2$kind == "premium"))
})

test_that("share query carries the planner facts and drops them when absent", {
  q <- build_share_query(PARAM_DEFAULTS, list(R = 1000), know = list(people = 3, months = 12, budget = 250000))
  back <- parse_share_query(shiny::parseQueryString(paste0("?", q)))
  expect_equal(back$know, list(people = 3, months = 12, budget = 250000))
  q2 <- build_share_query(PARAM_DEFAULTS, list(R = 1000))
  expect_false(grepl("people=|deadline=|budget=", q2))
  expect_equal(length(parse_share_query(shiny::parseQueryString(paste0("?", q2)))$know), 0)
  bad <- parse_share_query(list(mode = "manual", r = "100", people = "40", deadline = "0", budget = "5"))
  expect_equal(length(bad$know), 0)
})
