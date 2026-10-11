# UI helpers: pure tag builders that encode the app's UX contracts.
# No reactive state, no colours (CSS reads the --app-* tokens), testable with
# plain htmltools - see tests/testthat/test-ui-helpers.R.
#
# Contracts (from the data-app UX rules):
#   * a KPI shows value + reference + n (+ optional status word); it refuses to
#     render a bare number;
#   * an empty or failed view says what kind of empty it is and why;
#   * sections are named by the question they answer;
#   * every input has a real <label>, help is a popover with an accessible name.
# Each component carries a data-ux hook so a static checker can find it.

# ---- KPI tile ---------------------------------------------------------------
kpi_tile <- function(label, value, reference, n_text,
                     status = c("none", "ok", "watch", "action"),
                     status_label = NULL, note = NULL) {
  status <- match.arg(status)
  if (missing(reference) || is.null(reference) || missing(n_text) || is.null(n_text)) {
    stop("kpi_tile(): `reference` and `n_text` are required ",
         "(a number without its basis invites misreading).", call. = FALSE)
  }
  word <- switch(status, none = NULL,
    ok     = list("circle-check",         "Within plan"),
    watch  = list("triangle-exclamation", "Watch"),
    action = list("circle-xmark",         "Action needed"))
  if (!is.null(word) && !is.null(status_label)) word[[2]] <- status_label
  tags$div(
    class = "kpi", `data-ux` = "kpi", `data-status` = status,
    role = "group", `aria-label` = label,
    tags$div(class = "kpi-label", label),
    tags$div(class = "kpi-value", value),
    tags$div(class = "kpi-ref", reference),
    tags$div(class = "kpi-n", n_text),
    if (!is.null(word)) tags$div(class = "kpi-status",
      shiny::icon(word[[1]], `aria-hidden` = "true"), word[[2]]),
    if (!is.null(note)) tags$div(class = "kpi-note", note)
  )
}

# ---- Typed empty / error states -----------------------------------------------
state_kinds <- c("empty", "filtered", "insufficient", "error", "could_not_run", "stale")

state_panel <- function(kind = state_kinds, msg, why, action = NULL) {
  kind <- match.arg(kind)
  if (missing(why) || is.null(why) || !nzchar(paste(why, collapse = ""))) {
    stop("state_panel(): `why` is required; an empty view must say why it is empty.",
         call. = FALSE)
  }
  ico <- switch(kind,
    empty = "circle-info", filtered = "filter", insufficient = "chart-simple",
    error = "circle-exclamation", could_not_run = "triangle-exclamation", stale = "clock")
  tags$div(
    class = "state-panel", `data-ux` = "state", `data-kind` = kind,
    role = if (kind == "error") "alert" else "status",
    tags$div(class = "state-msg", shiny::icon(ico, `aria-hidden` = "true"), msg),
    tags$div(class = "state-why", why),
    if (!is.null(action)) tags$div(class = "state-action", action)
  )
}

# ---- Scope line: what the numbers are based on -------------------------------
scope_line <- function(...) {
  parts <- Filter(Negate(is.null), list(...))
  tags$p(class = "app-scope", `data-ux` = "scope", role = "status",
         paste(unlist(parts), collapse = " · "))
}

# ---- Question-named collapsible section --------------------------------------
question_section <- function(title, question = NULL, ..., open = FALSE, class = NULL) {
  tags$details(
    class = paste("app-section", class), open = if (isTRUE(open)) NA else NULL,
    tags$summary(
      tags$span(class = "section-title", title),
      if (!is.null(question)) tags$span(class = "section-question", question),
      shiny::icon("chevron-down", class = "section-chevron", `aria-hidden` = "true")
    ),
    tags$div(class = "section-body", ...)
  )
}

# ---- Chart card: header + one-line "what to notice" --------------------------
chart_card <- function(title, subtitle = NULL, ..., full_screen = TRUE) {
  bslib::card(
    class = "chart-card", full_screen = full_screen,
    bslib::card_header(
      tags$div(class = "chart-title", title),
      if (!is.null(subtitle)) tags$div(class = "chart-subtitle", subtitle)
    ),
    bslib::card_body(...)
  )
}

# ---- Labelled field with help popover ----------------------------------------
# `input` is a shiny input built with label = NULL; `input_id` is its id so the
# visible <label for> actually names the control for assistive technology.
help_trigger <- function(id, title) {
  tags$button(
    type = "button", id = id, class = "help-trigger",
    `aria-label` = paste("About", tolower(title)),
    shiny::icon("circle-question", `aria-hidden` = "true")
  )
}

field_with_help <- function(input, label, input_id, help_title, help_body,
                            hint = NULL, help_id = paste0(input_id, "_help")) {
  tags$div(
    class = "field",
    tags$div(
      class = "field-label-row",
      tags$label(class = "field-label", `for` = input_id, label),
      bslib::popover(
        help_trigger(help_id, help_title),
        help_body, title = help_title, placement = "right"
      )
    ),
    if (!is.null(hint)) tags$div(class = "field-hint", hint),
    input
  )
}

# ---- Estimate status word (pure) ---------------------------------------------
# One place decides how the plan is doing, so the hero, the strip and the PDF
# never disagree. Returns list(kind, word, detail).
estimate_status <- function(e) {
  premium <- round((e$compression_penalty - 1) * 100)
  if (!isTRUE(e$schedule_feasible)) {
    list(kind = "action", word = "Not feasible with this team cap",
         detail = sprintf("Needs %s to meet %s; your cap is %d.",
                          fmt_fte(e$final_people), fmt_months(e$final_schedule_months),
                          as.integer(min(e$params$max_team_size, 8))))
  } else if (e$compression_penalty > 1.0) {
    list(kind = "watch", word = sprintf("Compressed schedule, +%d%% cost", premium),
         detail = sprintf("Natural schedule %s, capped at %s.",
                          fmt_months(e$natural_schedule_months),
                          fmt_months(e$params$max_schedule_months)))
  } else {
    list(kind = "ok", word = "Within plan",
         detail = "Schedule and team fit your caps; no compression premium.")
  }
}

# ---- Range band: the honest ±30% on a scale that starts at zero -----------------
# Band width relative to zero shows how wide the uncertainty is; a fixed
# 0/50/100 track would not.
range_band <- function(low, mid, high, label = "Estimate range (±30%)") {
  top <- high * 1.06
  pct <- function(x) sprintf("%.1f%%", 100 * x / top)
  tags$div(
    class = "range-band", role = "img",
    `aria-label` = sprintf("%s: %s to %s, estimate %s", label,
                           fmt_usd(low), fmt_usd(high), fmt_usd(mid)),
    tags$div(
      class = "range-track",
      tags$div(class = "range-fill",
               style = sprintf("left:%s; width:%s;", pct(low), pct(high - low))),
      tags$div(class = "range-marker", style = sprintf("left:%s;", pct(mid)))
    ),
    tags$div(
      class = "range-labels",
      tags$span(class = "range-zero", "$0"),
      tags$span(class = "range-low",  style = sprintf("left:%s;", pct(low)),  fmt_usd(low)),
      tags$span(class = "range-high", style = sprintf("left:%s;", pct(high)), fmt_usd(high))
    ),
    tags$div(class = "range-caption", label)
  )
}

# ---- Hero estimate block ------------------------------------------------------
# The one bold element on the page: serif figure, range band, status word,
# three KPI tiles, scope line and an actions toolbar.
hero_estimate <- function(e, bd, source_label = NULL, actions = NULL, live_note = NULL) {
  st <- estimate_status(e)
  p  <- e$params

  third_tile <- if (!is.null(e$maintenance)) {
    m <- e$maintenance
    kpi_tile("Total cost of ownership", fmt_usd(m$tco),
             reference = sprintf("Build %s + %d yr maintenance", fmt_usd(e$cost_usd),
                                 m$maintenance_years),
             n_text = sprintf("Today's dollars at %.0f%%/yr", m$discount_rate * 100))
  } else {
    kpi_tile("Effort", paste0(format(round(e$effort_person_months, 1), nsmall = 1),
                              " person-months"),
             reference = "COCOMO II.2000 calibration",
             n_text = paste(fmt_int(bd$billable_code), "billable lines"))
  }

  excluded <- bd$total_code - bd$billable_code
  tags$section(
    class = "hero-block", `data-ux` = "hero", `aria-live` = "polite", `aria-atomic` = "true",
    tags$div(
      class = "hero-main",
      tags$div(
        class = "hero-figure-wrap",
        tags$div(class = "hero-caption", "Estimated development cost"),
        tags$div(class = "hero-figure", fmt_usd(e$cost_usd)),
        range_band(e$estimate_range$low, e$cost_usd, e$estimate_range$high),
        tags$div(
          class = paste0("status-word status-", st$kind), role = "status",
          shiny::icon(switch(st$kind, ok = "circle-check", watch = "triangle-exclamation",
                             action = "circle-xmark"), `aria-hidden` = "true"),
          tags$span(class = "status-text", st$word),
          tags$span(class = "status-detail", st$detail)
        )
      ),
      tags$div(
        class = "hero-kpis",
        kpi_tile("Schedule", fmt_months(e$final_schedule_months),
                 reference = paste("Cap", fmt_months(p$max_schedule_months)),
                 n_text = paste("Natural", fmt_months(e$natural_schedule_months)),
                 status = if (st$kind == "ok") "none" else st$kind,
                 status_label = if (st$kind == "watch") "Compressed" else if (st$kind == "action") "Over cap"),
        kpi_tile("Team", fmt_fte(e$final_people),
                 reference = sprintf("Cap %d people", as.integer(min(p$max_team_size, 8))),
                 n_text = sprintf("%s person-months ÷ %s",
                                  format(round(e$effort_person_months, 1), nsmall = 1),
                                  fmt_months(e$final_schedule_months))),
        third_tile
      )
    ),
    scope_line(
      paste(fmt_int(bd$billable_code), "billable lines"),
      if (excluded > 0) paste(fmt_int(excluded), "doc/config lines excluded"),
      paste(tools::toTitleCase(p$complexity), "complexity"),
      paste("Team experience", p$team_experience),
      paste(fmt_usd(p$avg_wage, exact = TRUE), "per developer-year"),
      if (!is.null(source_label)) paste("Source:", source_label)
    ),
    # Freshness for a calculator: the figures are computed live from the inputs,
    # never cached, so the note says so (and is machine-findable).
    if (!is.null(live_note)) tags$div(class = "hero-live-note", `data-ux` = "freshness",
                                      `data-state` = "fresh", role = "status", live_note),
    if (!is.null(actions)) tags$div(class = "hero-actions", actions)
  )
}

# ---- Shell pieces ------------------------------------------------------------
skip_link <- function(target = "#main") {
  tags$a(class = "skip-link", href = target, "Skip to main content")
}

app_footer <- function(version, owner, support_url = NULL, support_label = "Help and feedback",
                       name = "Software Cost Estimator") {
  tags$footer(
    class = "app-footer", `data-ux` = "footer", role = "contentinfo",
    tags$span(tags$strong(paste0(name, " v", version))),
    tags$span(
      class = "footer-right",
      owner,
      if (!is.null(support_url)) tags$a(href = support_url, target = "_blank",
                                        rel = "noopener", support_label)
    )
  )
}
