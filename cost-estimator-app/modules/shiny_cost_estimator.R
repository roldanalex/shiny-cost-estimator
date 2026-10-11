# Shiny App Cost Estimator (COCOMO II.2000-based)
# Usage: source this file and call estimate_shiny_cost(<code_lines>, <complexity>, <team_experience>, <reuse_factor>, <tool_support>)
#
# Model constants follow COCOMO II.2000 (Boehm et al., "Software Cost Estimation
# with COCOMO II", 2000): A = 2.94, C = 3.67, D = 0.28 + 0.2 * (B - 0.91).
# A single documented calibration multiplier EM_modern = 0.85 adjusts for modern
# high-level frameworks (net effective A ~= 2.50). It applies when
# framework = "modern" (the default); framework = "systems" keeps the published
# A for systems, embedded or legacy code.

# Language productivity factors (higher = more lines of that language per unit
# of effort, relative to R = 1.0). COCOMO II publishes no per-language factors;
# these are this tool's documented heuristic. Unlisted languages count at 1.0.
# Documentation/config formats (Markdown, YAML, JSON, ...) are excluded upstream.
LANGUAGE_PRODUCTIVITY <- c(
  "R" = 1.0, "Python" = 1.1, "SQL" = 1.3, "JavaScript" = 0.9, "TypeScript" = 0.9,
  "CSS" = 1.2, "Sass" = 1.2, "HTML" = 1.3,
  "Ruby" = 1.1, "PHP" = 1.1, "Julia" = 1.1,
  "Go" = 1.0, "Rust" = 1.0, "C#" = 1.0, "Kotlin" = 1.0, "Swift" = 1.0, "Scala" = 1.0,
  "Java" = 1.0, "C" = 1.0, "C++" = 1.0, "C Header" = 1.0, "Shell" = 1.0
)

#' Estimate cost, schedule, and team size for a Shiny app
#' @param code_lines Number of code lines (R + JS + CSS + Python + SQL)
#' @param complexity "low", "medium", or "high" (affects exponent)
#' @param team_experience 1 (novice) to 5 (expert)
#' @param reuse_factor 0.7 (lots of reuse) to 1.3 (little reuse)
#' @param tool_support 0.8 (excellent) to 1.2 (poor)
#' @param language_mix List with code lines by language (optional, for weighting)
#' @param avg_wage Average annual fully-loaded wage for cost estimation (default: 105000)
#' @param max_team_size Maximum team size constraint (default: 5)
#' @param max_schedule_months Maximum schedule constraint in months (default: 24)
#' @param rely Required reliability multiplier (0.82-1.26, default: 1.0)
#' @param cplx Product complexity multiplier (0.73-1.74, default: 1.0)
#' @param ruse Required reusability multiplier (0.95-1.24, default: 1.0)
#' @param pcon Personnel continuity multiplier (0.81-1.29, default: 1.0)
#' @param apex Application experience multiplier (0.81-1.22, default: 1.0)
#' @param maintenance_rate Annual maintenance as fraction of build cost (default: 0.20)
#' @param maintenance_years Number of years to project maintenance (default: 0)
#' @param discount_rate Annual discount rate for maintenance present value (0-0.25, default: 0.05)
#' @param framework "modern" (default) applies the 0.85 modern-framework calibration;
#'   "systems" keeps the published COCOMO II.2000 constant for systems, embedded or legacy code
#' @return List with cost, schedule, people, effort, constraints, estimate range, and maintenance
estimate_shiny_cost <- function(
  code_lines,
  complexity = "medium",
  team_experience = 4,
  reuse_factor = 1.0,
  tool_support = 1.0,
  language_mix = NULL,
  avg_wage = 105000,
  max_team_size = 5,
  max_schedule_months = 24,
  rely = 1.0,
  cplx = 1.0,
  ruse = 1.0,
  pcon = 1.0,
  apex = 1.0,
  maintenance_rate = 0.20,
  maintenance_years = 0,
  discount_rate = 0.05,
  framework = c("modern", "systems")
) {
  # Input validation
  stopifnot(is.numeric(code_lines), code_lines >= 0)
  complexity <- match.arg(complexity, c("low", "medium", "high"))
  framework <- match.arg(framework, c("modern", "systems"))
  stopifnot(is.numeric(team_experience), team_experience >= 1, team_experience <= 5)
  stopifnot(is.numeric(reuse_factor), reuse_factor >= 0.7, reuse_factor <= 1.3)
  stopifnot(is.numeric(tool_support), tool_support >= 0.8, tool_support <= 1.2)
  stopifnot(is.numeric(rely), rely >= 0.82, rely <= 1.26)
  stopifnot(is.numeric(cplx), cplx >= 0.73, cplx <= 1.74)
  stopifnot(is.numeric(ruse), ruse >= 0.95, ruse <= 1.24)
  stopifnot(is.numeric(pcon), pcon >= 0.81, pcon <= 1.29)
  stopifnot(is.numeric(apex), apex >= 0.81, apex <= 1.22)
  stopifnot(is.numeric(maintenance_rate), maintenance_rate >= 0, maintenance_rate <= 1)
  stopifnot(is.numeric(maintenance_years), maintenance_years >= 0)
  stopifnot(is.numeric(avg_wage), is.finite(avg_wage), avg_wage > 0)
  stopifnot(is.numeric(max_team_size), is.finite(max_team_size), max_team_size >= 1)
  stopifnot(is.numeric(max_schedule_months), is.finite(max_schedule_months), max_schedule_months > 0)
  stopifnot(is.numeric(discount_rate), discount_rate >= 0, discount_rate <= 0.25)

  # COCOMO II.2000 calibration (Boehm et al. 2000)
  A <- 2.94
  B <- switch(complexity, low = 1.02, medium = 1.10, high = 1.18)

  # Calculate effective KLOC with language weighting (LANGUAGE_PRODUCTIVITY)
  if (!is.null(language_mix)) {
    weighted_code <- 0
    for (lang in names(language_mix)) {
      productivity <- LANGUAGE_PRODUCTIVITY[lang]
      if (is.na(productivity)) productivity <- 1.0
      productivity <- unname(productivity)
      weighted_code <- weighted_code + (language_mix[[lang]] / productivity)
    }
    KLOC <- weighted_code / 1000
  } else {
    KLOC <- code_lines / 1000
  }

  # Effort multipliers
  EM_experience <- 1.2 - 0.05 * team_experience  # 1.15 (novice) to 0.95 (expert)
  EM_reuse <- reuse_factor
  EM_tools <- tool_support
  EM_modern <- if (framework == "modern") 0.85 else 1.0  # calibration; see header note

  # COCOMO II cost drivers
  EM_rely <- rely
  EM_cplx <- cplx
  EM_ruse <- ruse
  EM_pcon <- pcon
  EM_apex <- apex

  EM_total <- EM_experience * EM_reuse * EM_tools * EM_modern *
              EM_rely * EM_cplx * EM_ruse * EM_pcon * EM_apex

  # Base effort before multipliers (for waterfall chart)
  base_effort <- A * (KLOC ^ B)

  # Unconstrained effort (person-months)
  effort0 <- base_effort * EM_total

  # Nominal schedule, COCOMO II.2000: TDEV = C * PM^D, D anchored at B = 0.91
  C <- 3.67
  D <- 0.28 + 0.2 * (B - 0.91)
  nominal_schedule <- if (effort0 > 0) C * (effort0 ^ D) else 0

  monthly_wage <- avg_wage / 12
  max_realistic_people <- 8
  team_cap <- min(max_team_size, max_realistic_people)

  compression_penalty <- 1.0
  coordination_premium <- 1.0
  schedule_feasible <- TRUE

  if (effort0 > 0) {
    # Team sized from the nominal schedule, capped by the user's constraint
    final_people <- min(effort0 / nominal_schedule, team_cap)
    natural_schedule <- effort0 / final_people

    if (natural_schedule <= max_schedule_months) {
      final_schedule <- natural_schedule
      effort_final <- effort0
    } else {
      # Schedule compression: smooth penalty anchored to COCOMO II's SCED
      # driver (1.43x effort at 75% schedule => exponent log(1.43)/log(4/3)
      # ~= 1.25), capped at 2.0. Continuous at ratio = 1: no cost cliffs.
      final_schedule <- max_schedule_months
      ratio <- natural_schedule / final_schedule
      compression_penalty <- min(ratio ^ 1.25, 2.0)
      effort_final <- effort0 * compression_penalty
      # Identity restored: the displayed team is what the compressed
      # schedule actually requires. May exceed the team cap.
      final_people <- effort_final / final_schedule
      schedule_feasible <- final_people <= team_cap
    }

    if (final_people >= 6) {
      coordination_premium <- 1.1
    }

    cost <- effort_final * monthly_wage * coordination_premium
  } else {
    final_people <- 0
    natural_schedule <- 0
    final_schedule <- 0
    effort_final <- 0
    cost <- 0
  }

  average_monthly_cost <- if (final_schedule > 0) cost / final_schedule else 0

  # --- Estimate range (+/-30%, typical COCOMO II estimation accuracy band) ---
  # This is a heuristic accuracy band, NOT a statistical confidence interval.
  estimate_range <- list(
    low = round(cost * 0.70),
    high = round(cost * 1.30)
  )

  # --- Maintenance cost estimation ---
  maintenance <- NULL
  if (maintenance_years > 0) {
    annual_maintenance <- cost * maintenance_rate
    # Compound 5% annual escalation (turnover, entropy)
    yearly_costs <- numeric(maintenance_years)
    for (yr in seq_len(maintenance_years)) {
      yearly_costs[yr] <- annual_maintenance * (1.05 ^ (yr - 1))
    }
    pv_costs <- yearly_costs / (1 + discount_rate) ^ seq_len(maintenance_years)
    total_maintenance_nominal <- sum(yearly_costs)
    total_maintenance_pv <- sum(pv_costs)
    maintenance <- list(
      annual_maintenance = round(annual_maintenance),
      maintenance_years = maintenance_years,
      maintenance_rate = maintenance_rate,
      discount_rate = discount_rate,
      yearly_costs = round(yearly_costs),
      total_maintenance = round(total_maintenance_nominal),
      total_maintenance_nominal = round(total_maintenance_nominal),
      total_maintenance_pv = round(total_maintenance_pv),
      tco = round(cost + total_maintenance_pv)
    )
  }

  # --- Multiplier breakdown for waterfall chart ---
  multiplier_breakdown <- list(
    base_effort = round(base_effort, 2),
    EM_experience = EM_experience,
    EM_reuse = EM_reuse,
    EM_tools = EM_tools,
    EM_modern = EM_modern,
    EM_rely = EM_rely,
    EM_cplx = EM_cplx,
    EM_ruse = EM_ruse,
    EM_pcon = EM_pcon,
    EM_apex = EM_apex,
    EM_total = EM_total
  )

  list(
    code_lines = code_lines,
    effort_person_months = round(effort_final, 2),
    unconstrained_effort_pm = round(effort0, 2),
    schedule_months = round(nominal_schedule, 2),
    natural_schedule_months = round(natural_schedule, 2),
    cost_usd = round(cost),
    realistic_cost_usd = round(cost),  # deprecated alias of cost_usd
    final_people = round(final_people, 2),
    final_schedule_months = round(final_schedule, 2),
    compression_penalty = round(compression_penalty, 3),
    premium_multiplier = round(compression_penalty, 3),  # deprecated alias
    coordination_premium = coordination_premium,
    schedule_feasible = schedule_feasible,
    average_monthly_cost = round(average_monthly_cost),
    estimate_range = estimate_range,
    confidence_interval = estimate_range,  # deprecated alias of estimate_range
    maintenance = maintenance,
    multiplier_breakdown = multiplier_breakdown,
    params = list(
      complexity = complexity,
      team_experience = team_experience,
      reuse_factor = reuse_factor,
      tool_support = tool_support,
      avg_wage = avg_wage,
      max_team_size = max_team_size,
      max_schedule_months = max_schedule_months,
      rely = rely,
      cplx = cplx,
      ruse = ruse,
      pcon = pcon,
      apex = apex,
      maintenance_rate = maintenance_rate,
      maintenance_years = maintenance_years,
      discount_rate = discount_rate,
      framework = framework
    )
  )
}


#' Print a Shiny cost estimation report in scc-style format
#' @param result Output from estimate_shiny_cost()
print_shiny_cost_report <- function(result) {
  cat("\n-----------------------------------------------------------------------\n")
  cat(sprintf("%-25s %12s\n", "Metric", "Value"))
  cat("-----------------------------------------------------------------------\n")
  cat(sprintf("%-25s %12d\n", "Total Code Lines", result$code_lines))
  cat(sprintf("%-25s %12.2f\n", "Effort (person-months)", result$effort_person_months))
  cat(sprintf("%-25s %12.2f\n", "Schedule (months)", result$final_schedule_months))
  cat(sprintf("%-25s %12.2f\n", "People Required", result$final_people))
  cat(sprintf("%-25s $%11s\n", "Estimated Cost (USD)", format(result$cost_usd, big.mark=",")))
  if (!is.null(result$estimate_range)) {
    cat(sprintf("%-25s $%s - $%s\n", "Estimate Range (+/-30%)",
                format(result$estimate_range$low, big.mark=","),
                format(result$estimate_range$high, big.mark=",")))
  }
  cat("-----------------------------------------------------------------------\n")
  cat("Parameters Used:\n")
  cat(sprintf("  Complexity:        %s\n", result$params$complexity))
  cat(sprintf("  Team Experience:   %s\n", result$params$team_experience))
  cat(sprintf("  Reuse Factor:      %.2f\n", result$params$reuse_factor))
  cat(sprintf("  Tool Support:      %.2f\n", result$params$tool_support))
  if (result$compression_penalty > 1.0) {
    cat(sprintf("  Schedule Premium:  +%.0f%%\n", (result$compression_penalty - 1.0) * 100))
  }
  if (!result$schedule_feasible) {
    cat(sprintf("  WARNING: schedule requires %.1f people, above the %d-person cap\n",
                result$final_people, as.integer(min(result$params$max_team_size, 8))))
  }
  if (result$coordination_premium > 1.0) {
    cat(sprintf("  Coordination:      +%.0f%%\n", (result$coordination_premium - 1.0) * 100))
  }
  if (!is.null(result$maintenance)) {
    cat("-----------------------------------------------------------------------\n")
    cat("Maintenance & TCO:\n")
    cat(sprintf("  Annual Maintenance:  $%s\n", format(result$maintenance$annual_maintenance, big.mark=",")))
    cat(sprintf("  Maintenance Years:   %d\n", result$maintenance$maintenance_years))
    cat(sprintf("  Total Maintenance:   $%s (nominal), $%s (PV @ %.0f%%)\n",
                format(result$maintenance$total_maintenance_nominal, big.mark=","),
                format(result$maintenance$total_maintenance_pv, big.mark=","),
                result$maintenance$discount_rate * 100))
    cat(sprintf("  Total Cost (TCO):    $%s\n", format(result$maintenance$tco, big.mark=",")))
  }
  cat("-----------------------------------------------------------------------\n\n")
}

# Example usage:
# result <- estimate_shiny_cost(35000, complexity = "medium", team_experience = 4, reuse_factor = 0.9, tool_support = 0.9)
# print_shiny_cost_report(result)
