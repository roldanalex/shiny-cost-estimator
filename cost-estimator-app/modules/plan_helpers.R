# Plan advisor: deterministic planner over the estimation engine.
#
# Every (team cap, schedule cap) pair is priced through run_estimate(), so a
# recommendation is never an approximation of the engine: it IS an engine call
# with those caps, and "Apply" reproduces it exactly in the sidebar. Pure
# functions, no reactivity, no colours; unit-tested in test-plan-helpers.R.
#
# One guardrail the engine does not have: a practical schedule floor at 75% of
# the nominal schedule (Boehm's "impossible region", COCOMO II's SCED limit,
# Putnam/QSM minimum development time). Plans below it are shown on the curve
# but never recommended.

PLAN_TEAM_SIZES  <- 1:8
PLAN_CAPS        <- 3:60          # schedule caps the sidebar can express (months)
PLAN_FLOOR_SHARE <- 0.75

# ---- Grid --------------------------------------------------------------------
# For each team size: the natural (uncompressed) plan, priced with no schedule
# cap, plus one row per cap shorter than that natural schedule (compressed).
# `applicable` says whether the sidebar can express the plan's cap.
plan_grid <- function(bd, p) {
  base_over <- list(maintenance_rate = 0, maintenance_years = 0)
  e0 <- run_estimate(bd, p, overrides = c(base_over, list(max_team_size = 8, max_schedule_months = 1e6)))
  effort0        <- e0$unconstrained_effort_pm
  nominal_months <- e0$schedule_months
  nominal_people <- if (nominal_months > 0) effort0 / nominal_months else 0
  floor_months   <- max(1, PLAN_FLOOR_SHARE * nominal_months)

  if (effort0 <= 0) {
    return(list(grid = data.frame(), effort0 = 0, nominal_months = 0, nominal_people = 0,
                floor_months = 0, zero = TRUE))
  }

  row_of <- function(k, cap, r, uncompressed) {
    data.frame(
      k = k, cap = as.integer(cap), people = r$final_people, months = r$final_schedule_months,
      cost = r$cost_usd, premium = r$compression_penalty, feasible = isTRUE(r$schedule_feasible),
      coordination = r$coordination_premium > 1, uncompressed = uncompressed,
      applicable = cap <= max(PLAN_CAPS), stringsAsFactors = FALSE
    )
  }
  rows <- list()
  for (k in PLAN_TEAM_SIZES) {
    nat <- run_estimate(bd, p, overrides = c(base_over, list(max_team_size = k, max_schedule_months = 1e6)))
    natural_k <- nat$final_schedule_months
    nat_cap <- max(min(PLAN_CAPS), ceiling(natural_k))
    rows[[length(rows) + 1]] <- row_of(k, nat_cap, nat, TRUE)
    for (S in PLAN_CAPS[PLAN_CAPS < natural_k]) {
      r <- run_estimate(bd, p, overrides = c(base_over, list(max_team_size = k, max_schedule_months = S)))
      rows[[length(rows) + 1]] <- row_of(k, S, r, FALSE)
    }
  }
  grid <- do.call(rbind, rows)
  grid$practical <- grid$months >= floor_months - 1e-9
  list(grid = grid, effort0 = effort0, nominal_months = nominal_months,
       nominal_people = nominal_people, floor_months = floor_months, zero = FALSE)
}

# ---- One plan object, re-estimated from its own caps ----------------------------
plan_from_caps <- function(bd, p, k, cap, key, label, note = NULL) {
  e <- run_estimate(bd, p, overrides = list(max_team_size = k, max_schedule_months = cap,
                                            maintenance_rate = 0, maintenance_years = 0))
  st <- estimate_status(e)
  list(
    key = key, label = label, k = as.integer(k), cap = as.integer(cap),
    people = e$final_people, months = e$final_schedule_months, cost = e$cost_usd,
    range = e$estimate_range, premium = e$compression_penalty,
    coordination = e$coordination_premium > 1, feasible = isTRUE(e$schedule_feasible),
    applicable = cap <= max(PLAN_CAPS), status = st, note = note, est = e
  )
}

pick <- function(df, ...) {
  if (nrow(df) == 0) return(NULL)
  df[do.call(order, list(...)), , drop = FALSE][1, , drop = FALSE]
}

# ---- Recommendations ----------------------------------------------------------------
recommend_plans <- function(pg, bd, p, know = list(people = NULL, months = NULL, budget = NULL)) {
  out <- list(plans = list(), unmet = list())
  if (isTRUE(pg$zero)) return(out)
  g  <- pg$grid
  ok <- g[g$feasible & g$practical, , drop = FALSE]
  if (nrow(ok) == 0) return(out)

  mk <- function(row, key, label, note = NULL) plan_from_caps(bd, p, row$k, row$cap, key, label, note)

  cheapest <- pick(ok, ok$cost, ok$months, ok$k)
  fastest  <- pick(ok, ok$months, ok$cost, ok$k)
  plans <- list()

  # Facts first, so the cards lead with what the user knows.
  people <- know$people
  if (!is.null(people) && is.finite(people) && people >= 1) {
    people <- as.integer(min(8, round(people)))
    team_rows <- ok[ok$k == people, , drop = FALSE]
    tr <- pick(team_rows, team_rows$months, team_rows$cost)
    if (!is.null(tr)) {
      team <- mk(tr, "team", sprintf("With your %d %s", people, if (people == 1) "person" else "people"))
      up <- if (people < 8) pick(ok[ok$k == people + 1, , drop = FALSE], ok[ok$k == people + 1, "months"], ok[ok$k == people + 1, "cost"]) else NULL
      dn <- if (people > 1) pick(ok[ok$k == people - 1, , drop = FALSE], ok[ok$k == people - 1, "months"], ok[ok$k == people - 1, "cost"]) else NULL
      team$delta_up   <- if (!is.null(up)) list(months_saved = team$months - up$months, cost_added = up$cost - team$cost) else NULL
      team$delta_down <- if (!is.null(dn)) list(months_added = dn$months - team$months, cost_saved = team$cost - dn$cost) else NULL
      plans$team <- team
    }
  }

  deadline <- know$months
  if (!is.null(deadline) && is.finite(deadline) && deadline >= 1) {
    deadline <- as.integer(round(deadline))
    cands <- ok[ok$months <= deadline + 1e-9, , drop = FALSE]
    if (nrow(cands) > 0) {
      dr <- pick(cands, cands$k, cands$cost)
      # The plan at exactly the deadline cap with that team (uncompressed plans may be shorter)
      plans$deadline <- mk(dr, "deadline", sprintf("For your %d-month deadline", deadline))
      plans$deadline$achievable <- TRUE
      plans$deadline$deadline <- deadline
    } else {
      out$unmet$deadline <- list(
        deadline = deadline, floor = pg$floor_months,
        nearest = mk(fastest, "nearest", "Nearest achievable")
      )
    }
  }

  budget <- know$budget
  if (!is.null(budget) && is.finite(budget) && budget > 0) {
    within <- ok[ok$cost <= budget, , drop = FALSE]
    if (nrow(within) > 0) {
      fw <- pick(within, within$months, within$cost)
      plans$budget <- mk(fw, "budget", "Fastest within your budget")
      plans$budget$fits <- TRUE
      plans$budget$headroom <- budget - cheapest$cost
      plans$budget$budget <- budget
    } else {
      out$unmet$budget <- list(
        budget = budget, cheapest_cost = cheapest$cost,
        scope = scope_that_fits(bd, p, budget),
        levers = lever_savings(bd, p)
      )
    }
  }

  plans$cheapest <- mk(cheapest, "cheapest", "Cheapest",
                       note = if (cheapest$premium <= 1) "No rush premium" else NULL)
  if (!(fastest$k == cheapest$k && abs(fastest$months - cheapest$months) < 1e-6)) {
    plans$fastest <- mk(fastest, "fastest", "Fastest practical")
  }
  out$plans <- plans
  out
}

# ---- Budget inversion: how much of the scope fits --------------------------------------
# Scales the language mix by a share f in (0, 1]; cost is monotone in f, so a
# bisection finds the largest scope whose cheapest plan fits the budget.
scope_that_fits <- function(bd, p, budget, iterations = 25) {
  cost_at <- function(f) {
    mix <- lapply(bd$language_mix, function(v) v * f)
    bdf <- list(billable_code = sum(unlist(mix)), language_mix = mix)
    run_estimate(bdf, p, overrides = list(max_team_size = 8, max_schedule_months = 36,
                                          maintenance_rate = 0, maintenance_years = 0))$cost_usd
  }
  if (cost_at(1) <= budget) return(list(share = 1, lines = round(bd$billable_code), cost = cost_at(1)))
  lo <- 0; hi <- 1
  for (i in seq_len(iterations)) {
    mid <- (lo + hi) / 2
    if (cost_at(mid) <= budget) lo <- mid else hi <- mid
  }
  list(share = lo, lines = round(lo * bd$billable_code), cost = cost_at(lo))
}

# ---- Levers: what one level better reuse or tooling would save --------------------------
lever_savings <- function(bd, p) {
  base <- run_estimate(bd, p, overrides = list(max_team_size = 8, max_schedule_months = 36,
                                               maintenance_rate = 0, maintenance_years = 0))$cost_usd
  one <- function(key, param, title) {
    lv <- RATING_LEVELS[[key]]$levels
    cur <- nearest_level(p[[param]], key)
    idx <- which(abs(lv - cur) < 1e-9)[1]
    if (is.na(idx) || idx <= 1) return(NULL)
    better <- lv[idx - 1]
    over <- list(max_team_size = 8, max_schedule_months = 36, maintenance_rate = 0, maintenance_years = 0)
    over[[if (key == "reuse") "reuse_factor" else "tool_support"]] <- unname(better)
    cost <- run_estimate(bd, p, overrides = over)$cost_usd
    list(lever = title, from = sub(":.*$", "", names(lv)[idx]), to = sub(":.*$", "", names(lv)[idx - 1]),
         value = unname(better), cost = cost, saving = base - cost)
  }
  Filter(Negate(is.null), list(one("reuse", "reuse", "Code reuse"), one("tools", "tools", "Tooling")))
}

# ---- Staffing curve: fastest practical plan per team size ------------------------------
staffing_curve <- function(pg) {
  if (isTRUE(pg$zero)) return(data.frame())
  g <- pg$grid
  do.call(rbind, lapply(PLAN_TEAM_SIZES, function(k) {
    rows <- g[g$k == k, , drop = FALSE]
    fast <- pick(rows[rows$feasible & rows$practical, , drop = FALSE],
                 rows[rows$feasible & rows$practical, "months"], rows[rows$feasible & rows$practical, "cost"])
    nat  <- rows[rows$uncompressed, , drop = FALSE][1, , drop = FALSE]
    if (!is.null(fast) && !fast$applicable) fast <- NULL   # beyond the cap range: show natural only
    data.frame(k = k,
               months = if (is.null(fast)) NA_real_ else fast$months,
               cost = if (is.null(fast)) NA_real_ else fast$cost,
               cap = if (is.null(fast)) NA_integer_ else fast$cap,
               premium = if (is.null(fast)) NA_real_ else fast$premium,
               natural_months = nat$months, natural_cost = nat$cost,
               coordination = if (is.null(fast)) FALSE else fast$coordination)
  }))
}

# ---- Narrative: plain sentences from the computed plans -------------------------------
plan_narrative <- function(rec, pg, know = list()) {
  if (isTRUE(pg$zero)) return("Nothing to plan yet: there is no billable code in this estimate.")
  s <- character(0)
  pl <- rec$plans
  ppl <- function(k) sprintf("%d %s", as.integer(k), if (k == 1) "person" else "people")
  team_of <- function(pl) if (abs(pl$people - round(pl$people)) < 0.05) ppl(round(pl$people)) else sprintf("%s (team cap %d)", fmt_fte(pl$people), pl$k)

  if (!is.null(pl$team)) {
    t <- pl$team
    s <- c(s, sprintf("With %s, the fastest realistic delivery is %s at %s%s.",
                      ppl(t$k), fmt_months(t$months), fmt_usd(t$cost),
                      if (t$premium > 1) sprintf(" (includes a +%d%% rush premium)", round((t$premium - 1) * 100)) else ""))
    if (!is.null(t$delta_up)) {
      if (t$delta_up$months_saved > 0.05) {
        s <- c(s, sprintf("One more person would save %s %s.",
                          fmt_months(t$delta_up$months_saved),
                          if (t$delta_up$cost_added > 500) paste("for", fmt_usd(t$delta_up$cost_added), "more") else "at no extra cost"))
      } else {
        s <- c(s, "One more person would not make it faster.")
      }
    }
    if (!is.null(t$delta_down) && t$delta_down$months_added > 0.05) {
      s <- c(s, sprintf("One fewer would add %s%s.",
                        fmt_months(t$delta_down$months_added),
                        if (t$delta_down$cost_saved > 500) paste(" and save", fmt_usd(t$delta_down$cost_saved)) else ""))
    }
    if (t$k >= 6) s <- c(s, "Six or more people carry a 10% coordination overhead.")
    if (!t$applicable) s <- c(s, sprintf("That is longer than the %d-month cap the sidebar allows, so it cannot be applied directly.", max(PLAN_CAPS)))
  }

  if (!is.null(pl$deadline)) {
    d <- pl$deadline
    s <- c(s, sprintf("To deliver in %s you need at least %s, at %s%s.",
                      fmt_months(d$deadline), team_of(d), fmt_usd(d$cost),
                      if (d$premium > 1) sprintf(" with a +%d%% rush premium", round((d$premium - 1) * 100)) else " with no rush premium"))
  } else if (!is.null(rec$unmet$deadline)) {
    u <- rec$unmet$deadline
    s <- c(s, sprintf("%s is not achievable with up to 8 people: the practical floor for this project is %s. The nearest plan is %s with %s at %s.",
                      fmt_months(u$deadline), fmt_months(u$floor), fmt_months(u$nearest$months),
                      team_of(u$nearest), fmt_usd(u$nearest$cost)))
  }

  if (!is.null(pl$budget)) {
    b <- pl$budget
    s <- c(s, sprintf("The cheapest plan fits your budget with %s to spare; the fastest plan within budget is %s with %s.",
                      fmt_usd(max(0, b$headroom)), fmt_months(b$months), team_of(b)))
  } else if (!is.null(rec$unmet$budget)) {
    u <- rec$unmet$budget
    s <- c(s, sprintf("No plan fits %s: the cheapest is %s.", fmt_usd(u$budget, exact = TRUE), fmt_usd(u$cheapest_cost)))
    if (u$scope$share < 1) {
      s <- c(s, sprintf("About %d%% of the scope (%s lines) would fit.",
                        round(100 * u$scope$share), fmt_int(u$scope$lines)))
    }
    for (lv in u$levers) {
      if (lv$saving > 0) s <- c(s, sprintf("Moving %s from %s to %s would save about %s.",
                                           tolower(lv$lever), tolower(lv$from), tolower(lv$to), fmt_usd(lv$saving)))
    }
  }

  if (!is.null(pl$cheapest)) {
    c0 <- pl$cheapest
    s <- c(s, sprintf("The cheapest plan is %s for %s at %s%s.",
                      team_of(c0), fmt_months(c0$months), fmt_usd(c0$cost),
                      if (c0$premium <= 1) ": no rush premium" else ""))
  }
  # With a deadline in play the deadline sentence already covers speed.
  if (!is.null(pl$fastest) && is.null(pl$deadline) && is.null(rec$unmet$deadline)) {
    f <- pl$fastest
    extra <- if (!is.null(pl$cheapest) && pl$cheapest$cost > 0) round(100 * (f$cost / pl$cheapest$cost - 1)) else 0
    s <- c(s, sprintf("The fastest practical delivery is %s with %s at %s%s.",
                      fmt_months(f$months), team_of(f), fmt_usd(f$cost),
                      if (extra > 0) sprintf(" (+%d%%)", extra) else ""))
  }

  if (pg$nominal_people < 1) {
    s <- c(s, "This is a one-person project: adding people would not shorten it.")
  } else {
    s <- c(s, sprintf("Nothing gets faster than %s: that is 75%% of the natural schedule, the limit COCOMO II treats as practical.",
                      fmt_months(pg$floor_months)))
  }
  c(s, "Budget on the range, not the figure.")
}

# ---- Everything the UI and the PDF need, in one call --------------------------------------
plan_advice <- function(bd, p, know = list()) {
  pg  <- plan_grid(bd, p)
  rec <- recommend_plans(pg, bd, p, know)
  list(
    grid = pg, recommendations = rec, curve = staffing_curve(pg),
    narrative = plan_narrative(rec, pg, know), know = know,
    floor_months = pg$floor_months, nominal_months = pg$nominal_months
  )
}
