# Scenarios module
# Pins up to three estimates saved from the Estimate page and compares them on
# aligned bars and in a table. One shared wage keeps the dollar figures
# comparable; everything else (lines, complexity, team, caps) is editable per
# scenario, and the language mix, advanced drivers and maintenance settings
# travel with each saved scenario.

comparisonUI <- function(id) {
  ns <- NS(id)
  tags$main(id = "scenarios-main", class = "results-column scenarios", uiOutput(ns("body")))
}

comparisonServer <- function(id, mode = reactive("light")) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    slots <- reactiveVal(list())
    go_estimate <- reactiveVal(0)

    # ---- Add / remove -------------------------------------------------------
    add <- function(snap) {
      s <- slots()
      if (length(s) >= 3) {
        showNotification("Three scenarios is the maximum. Remove one to save another.",
                         type = "warning", duration = 6)
        return(NULL)
      }
      snap$id   <- paste0("s", format(as.numeric(Sys.time()) * 1000, scientific = FALSE), sample.int(999, 1))
      snap$name <- paste("Scenario", length(s) + 1)
      s[[length(s) + 1]] <- snap
      slots(s)

      rm_id <- paste0("rm_", snap$id)
      observeEvent(input[[rm_id]], {
        cur <- slots()
        keep <- Filter(function(x) x$id != snap$id, cur)
        for (i in seq_along(keep)) keep[[i]]$name <- paste("Scenario", i)
        slots(keep)
        showNotification("Scenario removed.", type = "message", duration = 3)
      }, ignoreInit = TRUE, once = TRUE)

      length(s)
    }

    observeEvent(input$go_estimate, go_estimate(go_estimate() + 1))
    for (i in 1:3) local({
      id <- paste0("go_estimate_slot", i)
      observeEvent(input[[id]], go_estimate(go_estimate() + 1), ignoreInit = TRUE)
    })

    # ---- Per-scenario inputs with fallbacks to the saved values ------------------
    val <- function(id, fallback) {
      v <- input[[id]]
      if (is.null(v) || length(v) != 1 || (is.character(v) && !nzchar(v))) fallback else v
    }
    num <- function(id, fallback) {
      v <- suppressWarnings(as.numeric(val(id, fallback)))
      if (length(v) != 1 || is.na(v) || !is.finite(v)) fallback else v
    }

    shared <- reactive({
      s <- slots(); req(length(s) > 0)
      p0 <- s[[1]]$params
      list(
        wage = { w <- num("wage", p0$wage); if (w < 50000 || w > 300000) p0$wage else w }
      )
    })

    scenario_estimates <- reactive({
      s <- slots(); req(length(s) > 0)
      sh <- shared()
      lapply(s, function(sc) {
        p   <- sc$params
        mix <- sc$language_mix
        total_saved <- sum(unlist(mix))
        lines <- num(paste0("lines_", sc$id), total_saved)
        scale <- if (total_saved > 0) lines / total_saved else 1
        mix_scaled <- lapply(mix, function(v) v * scale)
        bd <- list(billable_code = sum(unlist(mix_scaled)), language_mix = mix_scaled)
        p$complexity   <- val(paste0("cx_", sc$id), p$complexity)
        p$team_exp     <- num(paste0("te_", sc$id), p$team_exp)
        p$reuse        <- num(paste0("re_", sc$id), p$reuse)
        p$tools        <- num(paste0("to_", sc$id), p$tools)
        p$max_team     <- num(paste0("mt_", sc$id), p$max_team)
        p$max_schedule <- num(paste0("ms_", sc$id), p$max_schedule)
        p$wage         <- sh$wage
        est <- tryCatch(run_estimate(bd, p), error = function(e) NULL)
        changed <- !identical(p$complexity, sc$params$complexity) ||
          p$team_exp != sc$params$team_exp || p$reuse != sc$params$reuse ||
          p$tools != sc$params$tools || abs(lines - total_saved) > 0.5 ||
          sh$wage != sc$params$wage || p$max_team != sc$params$max_team ||
          p$max_schedule != sc$params$max_schedule
        list(sc = sc, params = p, est = est, lines = lines, changed = changed)
      })
    })

    # ---- Body ---------------------------------------------------------------------
    output$body <- renderUI({
      s <- slots()
      if (length(s) == 0) {
        return(tags$section(
          class = "welcome",
          tags$h2("Compare what-if scenarios"),
          tags$p(class = "lead",
            "Pin up to three estimates side by side: a smaller team, a shorter deadline, a different complexity. ",
            "Money and limits are shared so the dollar figures stay comparable."),
          state_panel("empty", "No scenarios saved yet",
                      "Run an estimate on the Estimate page, then choose Save as scenario. It appears here with its inputs ready to adjust.",
                      action = actionButton(ns("go_estimate"), "Go to Estimate", class = "btn-primary",
                                            icon = icon("arrow-left")))
        ))
      }
      p0 <- s[[1]]$params
      tagList(
        tags$section(
          class = "hero-block",
          tags$h2(class = "mb-1", "Scenarios"),
          tags$p(class = "text-muted mb-3",
            "Edit any scenario below; the comparison updates as you type. One wage applies to all of them so the dollars stay comparable."),
          tags$div(
            class = "shared-inputs", style = "max-width: 420px;",
            field_with_help(
              numericInput(ns("wage"), NULL, value = p0$wage, min = 50000, max = 300000, step = 5000, width = "100%"),
              label = "Cost per developer-year (USD), shared", input_id = ns("wage"),
              help_title = "Shared across scenarios",
              help_body = p("The same fully loaded developer-year cost applies to every scenario so the costs stay comparable."))
          )
        ),
        tags$div(
          class = "scenario-grid",
          lapply(s, scenario_card),
          lapply(seq_len(3 - length(s)), function(i) {
            tags$div(class = "scenario-slot",
              tags$div(
                tags$div(class = "slot-title", paste("Scenario", length(s) + i)),
                tags$p(class = "mb-2", "Free slot. Adjust the inputs on the Estimate page and choose Save as scenario."),
                actionButton(ns(paste0("go_estimate_slot", length(s) + i)), "Go to Estimate",
                             class = "btn-outline-secondary btn-sm")))
          })
        ),
        question_section(
          "How do they compare?", "Cost with its estimate range, schedule and team, on the same scales",
          open = TRUE,
          plotlyOutput(ns("comparison_chart"), height = "320px")
        ),
        question_section(
          "Side by side", "Inputs and results for every scenario", open = TRUE,
          uiOutput(ns("comparison_table"))
        )
      )
    })

    scenario_card <- function(sc) {
      p   <- sc$params
      mix <- sc$language_mix
      bslib::card(
        class = "scenario-card",
        bslib::card_header(
          tags$span(class = "font-serif", sc$name),
          actionButton(ns(paste0("rm_", sc$id)), "Remove", class = "btn-link btn-sm",
                       icon = icon("xmark"))
        ),
        bslib::card_body(
          uiOutput(ns(paste0("result_", sc$id))),
          tags$details(
            class = "sidebar-adv", open = NA,
            tags$summary("Inputs", icon("chevron-down", class = "section-chevron", `aria-hidden` = "true")),
            tags$div(
              class = "adv-body",
              tags$div(class = "field",
                tags$label(class = "field-label", `for` = ns(paste0("lines_", sc$id)), "Billable lines"),
                numericInput(ns(paste0("lines_", sc$id)), NULL, value = sum(unlist(mix)), min = 100, step = 500, width = "100%"),
                tags$div(class = "field-hint",
                  paste0("From ", sc$label, ": ", paste(sprintf("%s %s", fmt_int(unlist(mix)), names(mix)), collapse = ", ")))),
              tags$div(class = "field",
                tags$label(class = "field-label", `for` = ns(paste0("cx_", sc$id)), "Complexity"),
                selectInput(ns(paste0("cx_", sc$id)), NULL,
                            choices = c("Low" = "low", "Medium" = "medium", "High" = "high"),
                            selected = p$complexity, width = "100%")),
              tags$div(class = "field",
                tags$label(class = "field-label", `for` = ns(paste0("te_", sc$id)), "Team experience"),
                sliderInput(ns(paste0("te_", sc$id)), NULL, min = 1, max = 5, value = p$team_exp, step = 1,
                            ticks = FALSE, width = "100%")),
              tags$div(class = "field",
                tags$label(class = "field-label", `for` = ns(paste0("re_", sc$id)), "Code reuse"),
                selectInput(ns(paste0("re_", sc$id)), NULL, choices = rating_choices("reuse"),
                            selected = as.character(nearest_level(p$reuse, "reuse")), width = "100%")),
              tags$div(class = "field",
                tags$label(class = "field-label", `for` = ns(paste0("to_", sc$id)), "Tooling and process"),
                selectInput(ns(paste0("to_", sc$id)), NULL, choices = rating_choices("tools"),
                            selected = as.character(nearest_level(p$tools, "tools")), width = "100%")),
              tags$div(class = "field",
                tags$label(class = "field-label", `for` = ns(paste0("mt_", sc$id)), "Team cap"),
                sliderInput(ns(paste0("mt_", sc$id)), NULL, min = 1, max = 8, value = p$max_team, step = 1,
                            ticks = FALSE, post = " people", width = "100%")),
              tags$div(class = "field",
                tags$label(class = "field-label", `for` = ns(paste0("ms_", sc$id)), "Schedule cap"),
                sliderInput(ns(paste0("ms_", sc$id)), NULL, min = 3, max = 60, value = p$max_schedule, step = 1,
                            ticks = FALSE, post = " months", width = "100%")),
              tags$p(class = "field-hint",
                sprintf("Advanced drivers ×%.2f and %d maintenance years carried over from the saved estimate.",
                        p$rely * p$cplx * p$ruse * p$pcon * p$apex, p$maintenance_years))
            )
          )
        )
      )
    }

    # One result block per scenario, re-rendered live
    observe({
      ests <- scenario_estimates()
      for (item in ests) {
        local({
          it <- item
          output[[paste0("result_", it$sc$id)]] <- renderUI({
            if (is.null(it$est)) {
              return(state_panel("error", "Could not estimate this scenario",
                                 "One of its inputs is out of the model's range. Adjust the inputs below."))
            }
            e  <- it$est
            st <- estimate_status(e)
            tagList(
              tags$div(class = "hero-caption", "Estimated development cost"),
              tags$div(class = "hero-figure", style = "font-size: 2rem; margin-bottom: 6px;", fmt_usd(e$cost_usd)),
              tags$div(class = "field-hint",
                paste(fmt_usd(e$estimate_range$low), "to", fmt_usd(e$estimate_range$high), "(±30%)")),
              tags$div(
                class = "hero-kpis mt-2", style = "grid-template-columns: 1fr 1fr;",
                kpi_tile("Schedule", fmt_months(e$final_schedule_months),
                         reference = paste("Cap", fmt_months(e$params$max_schedule_months)),
                         n_text = paste("Natural", fmt_months(e$natural_schedule_months))),
                kpi_tile("Team", fmt_fte(e$final_people),
                         reference = sprintf("Cap %d", as.integer(min(e$params$max_team_size, 8))),
                         n_text = paste(format(round(e$effort_person_months, 1), nsmall = 1), "person-months"))
              ),
              tags$div(class = paste0("status-word status-", st$kind, " mt-2"),
                       icon(switch(st$kind, ok = "circle-check", watch = "triangle-exclamation", action = "circle-xmark"),
                            `aria-hidden` = "true"),
                       tags$span(class = "status-text", st$word)),
              if (it$changed) tags$div(class = "scenario-changed mt-2",
                                       icon("pen", `aria-hidden` = "true"), " Edited since it was saved")
            )
          })
        })
      }
    })

    # ---- Comparison chart: three aligned horizontal-bar panels ----------------------
    output$comparison_chart <- renderPlotly({
      ests <- Filter(function(x) !is.null(x$est), scenario_estimates())
      validate(need(length(ests) > 0, "Nothing to compare yet."))
      p <- app_palette(mode()); b <- app_plotly_base(mode())
      names_v <- vapply(ests, function(x) x$sc$name, character(1))
      cost    <- vapply(ests, function(x) x$est$cost_usd, numeric(1))
      low     <- vapply(ests, function(x) x$est$estimate_range$low, numeric(1))
      high    <- vapply(ests, function(x) x$est$estimate_range$high, numeric(1))
      sched   <- vapply(ests, function(x) x$est$final_schedule_months, numeric(1))
      team    <- vapply(ests, function(x) x$est$final_people, numeric(1))

      panel <- function(x, labels, title, hover, error_x = NULL, showticklabels = TRUE, inside = FALSE) {
        plot_ly(
          x = x, y = names_v, type = "bar", orientation = "h",
          marker = list(color = p$primary), error_x = error_x,
          text = labels, textposition = if (inside) "inside" else "outside",
          insidetextanchor = "start", cliponaxis = FALSE,
          textfont = list(color = if (inside) p$on_primary else p$ink, size = 12),
          hovertemplate = hover, showlegend = FALSE
        ) %>%
          layout(
            xaxis = c(b$xaxis, list(title = title, rangemode = "tozero")),
            yaxis = c(b$yaxis[setdiff(names(b$yaxis), "gridcolor")],
                      list(title = "", autorange = "reversed", showticklabels = showticklabels))
          )
      }
      subplot(
        panel(cost, fmt_usd_short(cost), "Cost (USD)", "%{y}<br>%{x:$,.0f}<extra></extra>",
              error_x = list(type = "data", symmetric = FALSE, array = high - cost,
                             arrayminus = cost - low, color = p$ink_muted, thickness = 1.5, width = 5),
              inside = TRUE),
        panel(sched, fmt_months(sched), "Schedule (months)", "%{y}<br>%{x} months<extra></extra>", showticklabels = FALSE),
        panel(team, fmt_fte(team), "Team (FTE)", "%{y}<br>%{x:.1f} FTE<extra></extra>", showticklabels = FALSE),
        nrows = 1, shareY = TRUE, titleX = TRUE, margin = 0.04, widths = c(0.44, 0.28, 0.28)
      ) %>%
        layout(paper_bgcolor = b$paper_bgcolor, plot_bgcolor = b$plot_bgcolor, font = b$font,
               hoverlabel = b$hoverlabel, showlegend = FALSE,
               margin = list(t = 16, r = 56, b = 56, l = 12)) %>%
        app_chart_config()
    })

    # ---- Comparison table -----------------------------------------------------------
    output$comparison_table <- renderUI({
      ests <- scenario_estimates()
      req(length(ests) > 0)
      base <- ests[[1]]$est
      cell <- function(f) lapply(ests, function(x) tags$td(class = "num", if (is.null(x$est)) "—" else f(x)))
      row  <- function(label, f) tags$tr(tags$th(scope = "row", label), cell(f))
      delta_cost <- function(x) {
        if (is.null(base) || identical(x$sc$id, ests[[1]]$sc$id)) return("baseline")
        d <- x$est$cost_usd - base$cost_usd
        paste0(if (d >= 0) "+" else "−", fmt_usd(abs(d)),
               sprintf(" (%+.0f%%)", 100 * d / base$cost_usd))
      }
      tags$div(class = "table-responsive",
        tags$table(
          class = "table table-sm compare-table",
          tags$thead(tags$tr(tags$th(scope = "col", ""), lapply(ests, function(x) tags$th(scope = "col", x$sc$name)))),
          tags$tbody(
            row("Billable lines",    function(x) fmt_int(x$lines)),
            row("Complexity",        function(x) tools::toTitleCase(x$params$complexity)),
            row("Team experience",   function(x) paste0(x$params$team_exp, " (", team_exp_word(x$params$team_exp), ")")),
            row("Code reuse",        function(x) sprintf("%.2f", x$params$reuse)),
            row("Tooling",           function(x) sprintf("%.2f", x$params$tools)),
            row("Team cap",          function(x) paste(x$params$max_team, "people")),
            row("Schedule cap",      function(x) fmt_months(x$params$max_schedule)),
            row("Estimated cost",    function(x) tags$strong(fmt_usd(x$est$cost_usd))),
            row("vs Scenario 1",     delta_cost),
            row("Estimate range",    function(x) paste(fmt_usd(x$est$estimate_range$low), "to", fmt_usd(x$est$estimate_range$high))),
            row("Schedule",          function(x) fmt_months(x$est$final_schedule_months)),
            row("Team",              function(x) fmt_fte(x$est$final_people)),
            row("Effort",            function(x) paste(format(round(x$est$effort_person_months, 1), nsmall = 1), "person-months")),
            row("Status",            function(x) estimate_status(x$est)$word),
            row("Total cost of ownership", function(x) if (is.null(x$est$maintenance)) "maintenance off" else fmt_usd(x$est$maintenance$tco))
          )
        )
      )
    })

    list(add = add, count = reactive(length(slots())), go_estimate = reactive(go_estimate()))
  })
}
