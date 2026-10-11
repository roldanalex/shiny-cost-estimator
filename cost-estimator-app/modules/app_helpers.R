# Pure helper functions (no Shiny session needed) - unit-tested in
# tests/testthat/test-app-helpers.R

#' Coerce a raw numeric input value to a safe non-negative count.
#' NULL, NA, non-numeric, non-finite, and negative values become 0.
clean_count <- function(x) {
  if (is.null(x) || length(x) != 1) return(0)
  x <- suppressWarnings(as.numeric(x))
  if (is.na(x) || !is.finite(x) || x < 0) return(0)
  x
}

#' Parse a URL query parameter as a bounded number.
#' Returns NULL (meaning "ignore") unless the value parses to a finite
#' number within [lo, hi].
parse_num_param <- function(x, lo = 0, hi = 5e6) {
  if (is.null(x) || length(x) != 1) return(NULL)
  v <- suppressWarnings(as.numeric(x))
  if (is.na(v) || !is.finite(v) || v < lo || v > hi) return(NULL)
  v
}

#' Build a validated language mix from raw manual-entry inputs.
#' Takes a named list of raw values; returns a named list containing only
#' languages with a positive, finite line count (possibly empty).
build_language_mix <- function(raw_mix) {
  cleaned <- lapply(raw_mix, clean_count)
  Filter(function(x) x > 0, cleaned)
}

# ---- Credit line for every output the tool produces -----------------------------
APP_AUTHOR_NAME <- "Alexis Roldan"
APP_SOURCE_URL  <- "https://github.com/roldanalex/shiny-app-valuation"

#' "Software Cost Estimator v2.2.0, developed by Alexis Roldan"
app_credit <- function(version = if (exists("APP_VERSION")) APP_VERSION else "2.2.0",
                       name = if (exists("APP_NAME")) APP_NAME else "Software Cost Estimator",
                       author = if (exists("APP_OWNER")) APP_OWNER else APP_AUTHOR_NAME) {
  sprintf("%s v%s, developed by %s", name, version, author)
}

# ---- Display formatting ------------------------------------------------------
# The engine returns exact figures; the screen and the PDF show them rounded so
# a ±30% estimate never reads as dollar-accurate. Rounding happens here only.

#' Round a dollar figure for display: nearest $100 below $100k, nearest $1k up
#' to $10M, nearest $10k above. Vectorised; NA stays NA.
round_usd <- function(x) {
  step <- ifelse(abs(x) >= 1e7, 1e4, ifelse(abs(x) >= 1e5, 1e3, 100))
  round(x / step) * step
}

#' "$487,000" style figure (display-rounded unless exact = TRUE)
fmt_usd <- function(x, exact = FALSE) {
  if (length(x) == 0) return(character(0))
  v <- if (exact) round(x) else round_usd(x)
  out <- paste0(ifelse(v < 0, "-$", "$"),
                format(abs(v), big.mark = ",", scientific = FALSE, trim = TRUE))
  out[is.na(x)] <- NA_character_
  out
}

#' Short dollar label for chart annotations: "$487k", "$1.24M", "$850"
fmt_usd_short <- function(x) {
  if (length(x) == 0) return(character(0))
  a <- abs(x)
  body <- ifelse(
    a >= 1e6, paste0(formatC(a / 1e6, digits = 3, format = "fg"), "M"),
    ifelse(a >= 1e3, paste0(formatC(round(a / 1e3), format = "d", big.mark = ","), "k"),
           formatC(round(a), format = "d"))
  )
  out <- paste0(ifelse(x < 0, "-$", "$"), body)
  out[is.na(x)] <- NA_character_
  out
}

#' "12 months" / "1 month" / "9.5 months"
fmt_months <- function(m) {
  v <- round(m, 1)
  paste0(ifelse(v == floor(v), format(v, nsmall = 0), format(v, nsmall = 1)),
         ifelse(v == 1, " month", " months"))
}

#' Team size as full-time equivalents: "3.2 FTE"
fmt_fte <- function(n) paste0(format(round(n, 1), nsmall = 1), " FTE")

#' Thousands-separated integer: "12,400"
fmt_int <- function(n) format(round(n), big.mark = ",", scientific = FALSE, trim = TRUE)

# ---- Parameter defaults and rating levels -------------------------------------
# One place for every default so Reset, the first-run example, the share link
# and the tests agree. Names match the params() list the analysis module reads.
PARAM_DEFAULTS <- list(
  complexity        = "medium",
  team_exp          = 4,
  reuse             = 1.0,
  tools             = 1.0,
  wage              = 105000,
  max_team          = 5,
  max_schedule      = 24,
  rely              = 1.0,
  cplx              = 1.0,
  ruse              = 1.0,
  pcon              = 1.0,
  apex              = 1.0,
  maintenance_rate  = 0.20,
  maintenance_years = 3,
  framework         = "modern"
)

# The worked example shown on first run (and used by "Run this example")
EXAMPLE_MIX <- list(R = 10000)

# Languages a user can enter by hand: every language the engine weights, plus
# Other for anything unlisted (priced at 1.0). Order: most common first.
MANUAL_LANGUAGES <- c("R", "Python", "JavaScript", "TypeScript", "SQL", "HTML", "CSS", "Sass",
                      "Java", "C#", "Go", "Rust", "C", "C++", "Kotlin", "Swift", "Scala",
                      "Ruby", "PHP", "Julia", "Shell", "Other")

# Kind of code: drives the 0.85 modern-framework calibration in the engine
FRAMEWORK_CHOICES <- c(
  "Modern framework or high-level language (R, Python, JavaScript, web, data)" = "modern",
  "Systems, embedded or legacy code (C, C++, Java, firmware)"                   = "systems"
)

#' A language id safe for Shiny input ids: "C++" -> "c_plus_plus", "C#" -> "c_sharp"
lang_slug <- function(lang) {
  x <- tolower(lang)
  x <- gsub("\\+", "_plus", x)
  x <- gsub("#", "_sharp", x)
  gsub("[^a-z0-9]+", "_", x)
}

# COCOMO II.2000 rating levels. Values are the published effort multipliers the
# engine already accepts; labels are what a non-specialist can answer.
RATING_LEVELS <- list(
  reuse = list(
    title = "Code reuse",
    levels = c("Very high: over half comes from existing packages or past projects" = 0.70,
               "High: substantial reuse of templates and internal libraries"          = 0.85,
               "Typical: about 10% reuse from standard libraries"                      = 1.00,
               "Low: mostly new code in a familiar domain"                             = 1.15,
               "None: everything built from scratch in a new domain"                   = 1.30)
  ),
  tools = list(
    title = "Tooling and process",
    levels = c("Excellent: IDE, version control, CI/CD, automated tests, code review" = 0.80,
               "Good: IDE, version control and tests; some manual steps"              = 0.90,
               "Standard: IDE and version control only"                               = 1.00,
               "Basic: limited tooling, manual deployments"                            = 1.10,
               "Poor: no version control, no IDE"                                      = 1.20)
  ),
  rely = list(
    title = "Required reliability",
    levels = c("Very low: prototype, failures barely matter"            = 0.82,
               "Low: internal tool, failures are easy to recover from"   = 0.92,
               "Nominal: standard business application"                   = 1.00,
               "High: failures cause real financial loss"                 = 1.10,
               "Very high: mission-critical, safety or large losses"      = 1.26)
  ),
  cplx = list(
    title = "Product complexity",
    levels = c("Very low: simple CRUD and forms"                       = 0.73,
               "Low: straightforward data display and reports"           = 0.87,
               "Nominal: moderate logic, typical web application"         = 1.00,
               "High: complex business rules or heavy integrations"       = 1.17,
               "Very high: ML/AI, real-time or distributed processing"    = 1.34,
               "Extra high: novel algorithms, hard real-time systems"     = 1.74)
  ),
  ruse = list(
    title = "Required reusability",
    levels = c("Low: built for this project only"                        = 0.95,
               "Nominal: some reuse within the project"                   = 1.00,
               "High: shared across a programme"                          = 1.07,
               "Very high: shared across the organisation"                = 1.15,
               "Extra high: a general library for many products"          = 1.24)
  ),
  pcon = list(
    title = "Team continuity",
    levels = c("Very high: stable team, almost no turnover"               = 0.81,
               "High: low turnover"                                       = 0.90,
               "Nominal: typical turnover"                                = 1.00,
               "Low: frequent rotation"                                   = 1.12,
               "Very low: constant churn and onboarding"                  = 1.29)
  ),
  apex = list(
    title = "Domain experience",
    levels = c("Very high: has built this kind of application before"    = 0.81,
               "High: knows the domain well"                              = 0.88,
               "Nominal: understands the domain, first app of this kind"  = 1.00,
               "Low: new to the domain"                                   = 1.10,
               "Very low: brand-new domain, long learning curve"          = 1.22)
  )
)

TEAM_EXP_WORDS <- c("Novice", "Beginner", "Competent", "Proficient", "Expert")

#' Snap a numeric value to the nearest published rating level
nearest_level <- function(x, key) {
  lv <- unname(RATING_LEVELS[[key]]$levels)
  x <- suppressWarnings(as.numeric(x))
  if (length(x) != 1 || is.na(x)) return(PARAM_DEFAULTS[[key]])
  lv[which.min(abs(lv - x))]
}

#' Choices vector for a rating selectInput (values as character for Shiny)
rating_choices <- function(key) {
  lv <- RATING_LEVELS[[key]]$levels
  setNames(as.character(lv), names(lv))
}

#' Word for a 1-5 team experience score
team_exp_word <- function(n) {
  n <- suppressWarnings(as.integer(round(n)))
  if (length(n) != 1 || is.na(n) || n < 1 || n > 5) return("")
  TEAM_EXP_WORDS[n]
}

# ---- Share link: every input that moves the number, both directions ------------
# v2.2 links carry the language mix as one key: langs=R:18000,Python:4000.
# The six v2.1 keys (r, py, js, sql, css, other) still parse so old links work.
LEGACY_SHARE_KEYS <- c(
  r = "R", py = "Python", js = "JavaScript", sql = "SQL", css = "CSS", other = "Other"
)

#' Clean a language mix: known names kept, counts sanitised, zeros dropped.
#' Unknown names are kept too (they price at 1.0), so a scan of any language shares.
clean_language_mix <- function(mix) {
  out <- list()
  for (nm in names(mix)) {
    v <- clean_count(mix[[nm]])
    if (v > 0 && nzchar(nm)) out[[nm]] <- v
  }
  out
}

#' Encode a mix as "R:18000,Python:4000" (names URL-safe; counts as integers)
encode_langs <- function(mix) {
  mix <- clean_language_mix(mix)
  if (length(mix) == 0) return("")
  paste0(utils::URLencode(names(mix), reserved = TRUE), ":",
         format(round(unlist(mix)), scientific = FALSE, trim = TRUE), collapse = ",")
}

#' Decode "R:18000,Python:4000" back to a bounded mix (unknown entries dropped)
decode_langs <- function(x) {
  if (is.null(x) || !nzchar(x)) return(list())
  out <- list()
  for (pair in strsplit(x, ",", fixed = TRUE)[[1]]) {
    kv <- strsplit(pair, ":", fixed = TRUE)[[1]]
    if (length(kv) != 2) next
    nm <- utils::URLdecode(kv[1])
    v  <- parse_num_param(kv[2])
    if (!is.null(v) && v > 0 && nzchar(nm) && nchar(nm) <= 40) out[[nm]] <- v
  }
  out
}

#' Query string (without the leading "?") that reproduces an estimate.
#' `know` (people, months, budget) are the optional planner facts.
build_share_query <- function(params, mix, know = NULL) {
  p <- utils::modifyList(PARAM_DEFAULTS, Filter(Negate(is.null), params))
  num <- function(x) format(x, scientific = FALSE, trim = TRUE)
  parts <- c(
    mode = "manual",
    langs = encode_langs(mix),
    complexity = p$complexity, team = num(p$team_exp),
    reuse = num(p$reuse), tools = num(p$tools), wage = num(p$wage),
    maxteam = num(p$max_team), maxsched = num(p$max_schedule),
    rely = num(p$rely), cplx = num(p$cplx), ruse = num(p$ruse),
    pcon = num(p$pcon), apex = num(p$apex),
    mrate = num(p$maintenance_rate), myears = num(p$maintenance_years),
    fw = p$framework
  )
  if (!is.null(know)) {
    for (k in c("people", "months", "budget")) {
      v <- suppressWarnings(as.numeric(know[[k]]))
      if (length(v) == 1 && is.finite(v) && v > 0)
        parts[[c(people = "people", months = "deadline", budget = "budget")[[k]]]] <- num(v)
    }
  }
  # langs is already encoded; everything else is encoded here
  enc <- vapply(names(parts), function(n) if (n == "langs") parts[[n]] else
    utils::URLencode(unname(parts[[n]]), reserved = TRUE), character(1))
  paste0(names(parts), "=", enc, collapse = "&")
}

#' Parse a query list back into validated inputs. Returns NULL unless
#' mode=manual; otherwise list(mix, params, know) with only the values that
#' passed their bounds (rating values snap to a level).
parse_share_query <- function(query) {
  if (is.null(query$mode) || !identical(query$mode, "manual")) return(NULL)
  mix <- decode_langs(query$langs)
  if (length(mix) == 0) {
    for (k in names(LEGACY_SHARE_KEYS)) {
      v <- parse_num_param(query[[k]])
      if (!is.null(v) && v > 0) mix[[LEGACY_SHARE_KEYS[[k]]]] <- v
    }
  }
  p <- list()
  if (!is.null(query$complexity) && query$complexity %in% c("low", "medium", "high"))
    p$complexity <- query$complexity
  t <- parse_num_param(query$team, 1, 5);          if (!is.null(t)) p$team_exp <- round(t)
  w <- parse_num_param(query$wage, 50000, 300000); if (!is.null(w)) p$wage <- w
  mt <- parse_num_param(query$maxteam, 1, 8);      if (!is.null(mt)) p$max_team <- round(mt)
  ms <- parse_num_param(query$maxsched, 3, 60);    if (!is.null(ms)) p$max_schedule <- round(ms)
  for (k in c("reuse", "tools", "rely", "cplx", "ruse", "pcon", "apex")) {
    v <- parse_num_param(query[[k]], 0.5, 2)
    if (!is.null(v)) p[[k]] <- nearest_level(v, k)
  }
  mr <- parse_num_param(query$mrate, 0, 0.40);     if (!is.null(mr)) p$maintenance_rate <- mr
  my <- parse_num_param(query$myears, 0, 10);      if (!is.null(my)) p$maintenance_years <- round(my)
  if (!is.null(query$fw) && query$fw %in% c("modern", "systems")) p$framework <- query$fw
  know <- list()
  kp <- parse_num_param(query$people, 1, 8);        if (!is.null(kp)) know$people <- round(kp)
  kd <- parse_num_param(query$deadline, 1, 60);     if (!is.null(kd)) know$months <- round(kd)
  kb <- parse_num_param(query$budget, 1000, 1e9);   if (!is.null(kb)) know$budget <- kb
  list(mix = mix, params = p, know = know)
}

# ---- One cost decomposition for every view ---------------------------------------
# The waterfall, the ranked driver bars, the text report and the PDF all read
# this table, so they can never disagree about what a factor is worth.
# Columns: name, delta (USD), kind (base | multiplier | premium | total), running.
cost_steps <- function(e) {
  mb   <- e$multiplier_breakdown
  rate <- e$params$avg_wage / 12
  base <- mb$base_effort * rate

  drivers <- list(
    list(name = "Team experience",  val = mb$EM_experience, always = TRUE),
    list(name = "Code reuse",       val = mb$EM_reuse,      always = TRUE),
    list(name = "Tooling",          val = mb$EM_tools,      always = TRUE),
    list(name = "Framework calibration", val = mb$EM_modern, always = TRUE),
    list(name = "Reliability",      val = mb$EM_rely,       always = FALSE),
    list(name = "Product complexity", val = mb$EM_cplx,     always = FALSE),
    list(name = "Reusability",      val = mb$EM_ruse,       always = FALSE),
    list(name = "Team continuity",  val = mb$EM_pcon,       always = FALSE),
    list(name = "Domain experience", val = mb$EM_apex,      always = FALSE)
  )

  rows <- data.frame(name = "Base effort", delta = base, kind = "base",
                     stringsAsFactors = FALSE)
  running <- base
  for (d in drivers) {
    if (!d$always && abs(d$val - 1) < 1e-9) next
    delta <- running * (d$val - 1)
    rows <- rbind(rows, data.frame(name = d$name, delta = delta, kind = "multiplier",
                                   stringsAsFactors = FALSE))
    running <- running + delta
  }
  if (e$compression_penalty > 1.0) {
    delta <- running * (e$compression_penalty - 1)
    rows <- rbind(rows, data.frame(name = "Schedule compression", delta = delta,
                                   kind = "premium", stringsAsFactors = FALSE))
    running <- running + delta
  }
  if (e$coordination_premium > 1.0) {
    delta <- running * (e$coordination_premium - 1)
    rows <- rbind(rows, data.frame(name = "Coordination overhead", delta = delta,
                                   kind = "premium", stringsAsFactors = FALSE))
    running <- running + delta
  }
  # The engine rounds effort before pricing it; fold that residual (a few
  # dollars) into the last step so the steps sum exactly to the headline.
  residual <- e$cost_usd - running
  rows$delta[nrow(rows)] <- rows$delta[nrow(rows)] + residual
  rows <- rbind(rows, data.frame(name = "Estimated cost", delta = e$cost_usd,
                                 kind = "total", stringsAsFactors = FALSE))
  rows$running <- c(cumsum(rows$delta[rows$kind != "total"]), e$cost_usd)
  rows
}
