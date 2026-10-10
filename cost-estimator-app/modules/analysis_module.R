# Analysis results module
# Renders the first-run screen, the hero estimate, the question-named sections
# (charts, TCO, assumptions) and the summary strip; owns the PDF, CSV and JSON
# downloads. Every number comes from estimate_shiny_cost() and cost_steps(), so
# the hero, the charts, the text report and the PDF always agree. Colours come
# from modules/theme.R (app_palette(mode)).

analysisResultsUI <- function(id) {
  ns <- NS(id)
  tagList(
    tags$div(class = "results-column", uiOutput(ns("results_body"))),
    uiOutput(ns("summary_strip"))
  )
}

# Split analysis data into billable / non-billable views.
# Manual-entry mixes are fully billable; repo scans carry a Billable column.
split_billable <- function(data) {
  if (!is.null(data$lang_summary)) {
    df <- data$lang_summary
    if (is.null(df$Billable)) df$Billable <- TRUE
    billable <- df[df$Billable, , drop = FALSE]
    list(
      lang_df       = df,
      total_code    = sum(df$Code),
      billable_code = sum(billable$Code),
      language_mix  = as.list(setNames(billable$Code, billable$Language)),
      has_docs      = any(!df$Billable & df$Code > 0)
    )
  } else {
    mix <- data$language_mix
    list(
      lang_df       = data.frame(Language = names(mix), Code = unlist(mix),
                                 Billable = TRUE, stringsAsFactors = FALSE),
      total_code    = sum(unlist(mix)),
      billable_code = sum(unlist(mix)),
      language_mix  = mix,
      has_docs      = FALSE
    )
  }
}

# Call the engine with the current sidebar params over a given language mix
run_estimate <- function(bd, p, overrides = list()) {
  args <- list(
    code_lines          = bd$billable_code,
    complexity          = p$complexity,
    team_experience     = p$team_exp,
    reuse_factor        = p$reuse,
    tool_support        = p$tools,
    language_mix        = bd$language_mix,
    avg_wage            = if (!is.null(p$wage))         p$wage         else PARAM_DEFAULTS$wage,
    max_team_size       = if (!is.null(p$max_team))     p$max_team     else PARAM_DEFAULTS$max_team,
    max_schedule_months = if (!is.null(p$max_schedule)) p$max_schedule else PARAM_DEFAULTS$max_schedule,
    rely                = if (!is.null(p$rely)) p$rely else 1.0,
    cplx                = if (!is.null(p$cplx)) p$cplx else 1.0,
    ruse                = if (!is.null(p$ruse)) p$ruse else 1.0,
    pcon                = if (!is.null(p$pcon)) p$pcon else 1.0,
    apex                = if (!is.null(p$apex)) p$apex else 1.0,
    maintenance_rate    = if (!is.null(p$maintenance_rate))  p$maintenance_rate  else PARAM_DEFAULTS$maintenance_rate,
    maintenance_years   = if (!is.null(p$maintenance_years)) p$maintenance_years else 0
  )
  args[names(overrides)] <- overrides
  do.call(estimate_shiny_cost, args)
}

# ---- First-run screen ----------------------------------------------------------
welcome_ui <- function(ns, show_local) {
  ex <- estimate_shiny_cost(
    EXAMPLE_MIX$R, complexity = PARAM_DEFAULTS$complexity,
    team_experience = PARAM_DEFAULTS$team_exp, language_mix = EXAMPLE_MIX,
    maintenance_years = PARAM_DEFAULTS$maintenance_years
  )
  way <- function(icon_name, title, text) {
    tags$div(class = "way",
      tags$div(class = "way-title", icon(icon_name, `aria-hidden` = "true"), title),
      tags$p(text))
  }
  tags$section(
    class = "welcome", `aria-labelledby` = ns("welcome_title"),
    tags$h2(id = ns("welcome_title"), "What would it cost to build this?"),
    tags$p(class = "lead",
      "Describe the project, or let the app count its code, and get the development cost, ",
      "schedule, team size and total cost of ownership from the COCOMO II model, with a PDF you can forward. ",
      "Only know your team or your deadline? Run an estimate, then open ", tags$em("What plan should I choose?"), "."),
    state_panel(
      "empty", "No estimate yet",
      "Fill in the inputs on the left and choose Run estimate, or start from the worked example below."
    ),
    tags$div(
      class = "welcome-ways",
      way("keyboard", "Manual entry", "Type rough line counts per language. A guess is fine; refine as you learn more."),
      way("file-zipper", "ZIP upload", "Upload a zipped repository (up to 50 MB). Languages are detected and counted automatically."),
      if (show_local) way("folder-open", "Local folder", "Point at a repository on this computer and scan it in place.")
      else way("file-pdf", "PDF report", "Every estimate exports to a client-ready report with charts, assumptions and method.")
    ),
    tags$div(
      class = "welcome-example",
      tags$span(class = "example-figure", fmt_usd(ex$cost_usd)),
      tags$span(class = "example-meta",
        sprintf("for %s lines of R, medium complexity, team experience %d, %s per developer-year",
                fmt_int(EXAMPLE_MIX$R), PARAM_DEFAULTS$team_exp,
                fmt_usd(PARAM_DEFAULTS$wage, exact = TRUE))),
      actionButton(ns("run_example"), "Run this example", class = "btn-primary",
                   icon = icon("play"))
    )
  )
}

# ---- Hero actions ---------------------------------------------------------------
hero_actions <- function(ns, pdf_available) {
  tagList(
    if (pdf_available) {
      downloadButton(ns("download_pdf"), "Download PDF report",
                     class = "btn-primary", icon = icon("file-pdf"))
    } else {
      tags$button(type = "button", class = "btn btn-outline-secondary", disabled = NA,
                  title = "PDF export needs Quarto on the server",
                  icon("file-pdf", `aria-hidden` = "true"), " PDF report unavailable here")
    },
    actionButton(ns("save_scenario"), "Save as scenario", class = "btn-outline-secondary",
                 icon = icon("layer-group")),
    tags$button(type = "button", class = "btn btn-outline-secondary", `data-copy-url` = "1",
                title = "Copy a link that reopens this exact estimate",
                icon("link", `aria-hidden` = "true"), " Copy link"),
    downloadButton(ns("download_csv"), "CSV", class = "btn-outline-secondary btn-sm",
                   icon = icon("table")),
    downloadButton(ns("download_json"), "JSON", class = "btn-outline-secondary btn-sm",
                   icon = icon("code"))
  )
}

# ---- Plan advisor section --------------------------------------------------------
plan_section_ui <- function(ns) {
  question_section(
    "What plan should I choose?", "Cheapest, fastest, or built around what you already know",
    open = TRUE, class = "plan-section",
    tags$div(
      class = "plan-know",
      field_with_help(
        numericInput(ns("know_people"), NULL, value = NULL, min = 1, max = 8, step = 1, width = "100%"),
        label = "People available", input_id = ns("know_people"), help_title = "People available",
        help_body = p("How many developers you can put on this, 1 to 8. Leave blank if you do not know; the planner will suggest a team.")),
      field_with_help(
        numericInput(ns("know_months"), NULL, value = NULL, min = 1, max = 60, step = 1, width = "100%"),
        label = "Deadline (months)", input_id = ns("know_months"), help_title = "Deadline",
        help_body = p("When it has to be done. The planner finds the smallest team that meets it, or says it cannot be met and names the nearest date.")),
      field_with_help(
        numericInput(ns("know_budget"), NULL, value = NULL, min = 1000, step = 10000, width = "100%"),
        label = "Budget (USD)", input_id = ns("know_budget"), help_title = "Budget",
        help_body = p("What you can spend on the build. If no plan fits, the planner says how much of the scope would, and which input would close the gap."))
    ),
    tags$p(class = "plan-know-hint", "All three are optional. With none, you get the cheapest plan, the fastest practical one, and the staffing curve."),
    uiOutput(ns("plan_advice_ui")),
    uiOutput(ns("plan_cards")),
    plotlyOutput(ns("staffing_chart"), height = "340px"),
    tags$p(class = "plan-note",
      "Build cost only; maintenance and the \u00b130% range apply on top. Plans shorter than 75% of the natural schedule are shown on the curve but never recommended: COCOMO II treats them as impractical.")
  )
}

# ---- Server --------------------------------------------------------------------
analysisResultsServer <- function(id, analysis_data, params, mode = reactive("light"),
                                  pdf_available = FALSE) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    has_data <- reactive({
      d <- analysis_data()
      !is.null(d) && is.null(d$error)
    })

    billable_data <- reactive({
      req(has_data())
      split_billable(analysis_data())
    })

    est   <- reactive(run_estimate(billable_data(), params()))
    steps <- reactive(cost_steps(est()))
    pal   <- reactive(app_palette(mode()))
    base  <- reactive(app_plotly_base(mode()))

    # Cost at every schedule cap the slider offers (maintenance excluded, as
    # in the headline). `feasible` marks caps the team cap can actually meet.
    tradeoff_curve <- reactive({
      bd <- billable_data()
      p  <- params()
      caps <- seq(3, 60, by = 1)
      rows <- lapply(caps, function(s) {
        r <- tryCatch(run_estimate(bd, p, overrides = list(
          max_schedule_months = s, maintenance_rate = 0, maintenance_years = 0)),
          error = function(err) NULL)
        if (is.null(r)) return(data.frame(schedule = s, cost = NA_real_, feasible = NA))
        data.frame(schedule = s, cost = r$cost_usd, feasible = isTRUE(r$schedule_feasible))
      })
      do.call(rbind, rows)
    })

    # ========================================================================
    # RESULTS BODY: welcome -> error -> hero + sections
    # ========================================================================
    output$results_body <- renderUI({
      d <- analysis_data()
      if (is.null(d)) return(welcome_ui(ns, show_local = !nzchar(Sys.getenv("R_CONFIG_ACTIVE"))))
      if (!is.null(d$error)) {
        return(state_panel(
          "error", d$error$msg, d$error$why,
          action = actionButton(ns("run_example"), "Run the worked example instead",
                                class = "btn-outline-secondary")
        ))
      }
      e  <- est()
      bd <- billable_data()

      tagList(
        hero_estimate(
          e, bd, source_label = d$source_label,
          actions   = hero_actions(ns, pdf_available),
          live_note = "Recalculates as you change the parameters on the left. Line counts and uploads need Run estimate."
        ),
        plan_section_ui(ns),
        tags$div(
          class = "section-grid",
          question_section(
            "How is the cost built?", "From base effort to the final figure, one factor at a time",
            open = TRUE,
            plotlyOutput(ns("waterfall"), height = "380px"),
            tags$p(class = "chart-note",
              "Base effort is priced at your developer-year cost. Each bar adds or removes what that factor is worth; the bars sum exactly to the estimate.")
          ),
          question_section(
            "What if the deadline moves?", "Cost at each schedule cap; the marker is your cap",
            open = TRUE,
            plotlyOutput(ns("tradeoff"), height = "380px"),
            tags$p(class = "chart-note",
              "Shaded caps are shorter than the natural schedule and carry a compression premium. Hollow points need more people than your team cap allows.")
          )
        ),
        question_section(
          "Which choices matter most?", "Dollars each driver adds or saves, largest first",
          plotlyOutput(ns("drivers_ranked"), height = "340px"),
          tags$p(class = "chart-note",
            "The same steps as the waterfall, ranked. Drivers at their nominal level add nothing and are not shown.")
        ),
        question_section(
          "What is the code made of?", "Lines by language; grey bars are documentation and configuration, which are never billed",
          plotlyOutput(ns("lang_bars"), height = "320px")
        ),
        question_section(
          "How sensitive is the estimate?", "Cost across team experience and complexity, everything else held at your values",
          plotlyOutput(ns("sensitivity"), height = "380px")
        ),
        question_section(
          "What does it cost to keep running?", "Maintenance and total cost of ownership",
          uiOutput(ns("maintenance_ui"))
        ),
        question_section(
          "Assumptions and data", "Every input behind the number",
          DTOutput(ns("details_table")),
          tags$h4(class = "mt-4", "Text report"),
          verbatimTextOutput(ns("estimate_text"))
        )
      )
    })

    # ========================================================================
    # WATERFALL: one decomposition, labelled, totals exactly to the hero
    # ========================================================================
    output$waterfall <- renderPlotly({
      s <- steps(); p <- pal(); b <- base()
      measure <- ifelse(s$kind == "base", "absolute", ifelse(s$kind == "total", "total", "relative"))
      labels  <- ifelse(s$kind %in% c("base", "total"), fmt_usd_short(s$delta),
                        ifelse(s$delta >= 0, paste0("+", fmt_usd_short(s$delta)),
                               paste0("−", fmt_usd_short(abs(s$delta)))))
      plot_ly(
        type = "waterfall", x = s$name, y = s$delta, measure = measure,
        text = labels, textposition = "outside", cliponaxis = FALSE,
        textfont = list(color = p$ink, size = 12),
        connector  = list(line = list(color = p$border, width = 1)),
        decreasing = list(marker = list(color = p$decrease)),
        increasing = list(marker = list(color = p$increase)),
        totals     = list(marker = list(color = p$primary)),
        hovertemplate = "%{x}<br>%{y:$,.0f}<extra></extra>"
      ) %>%
        layout(
          xaxis = c(b$xaxis, list(title = "", categoryorder = "array", categoryarray = s$name,
                                  tickangle = if (nrow(s) >= 6) -30 else 0)),
          yaxis = c(b$yaxis, list(title = "", tickprefix = "$", tickformat = "~s", rangemode = "tozero")),
          showlegend = FALSE, paper_bgcolor = b$paper_bgcolor, plot_bgcolor = b$plot_bgcolor,
          font = b$font, hoverlabel = b$hoverlabel,
          margin = list(t = 28, r = 16, b = if (nrow(s) >= 6) 96 else 56, l = 56)
        ) %>% app_chart_config()
    })

    # ========================================================================
    # TRADEOFF: cost vs schedule cap, marker at the cap you chose
    # ========================================================================
    output$tradeoff <- renderPlotly({
      e <- est(); curve <- tradeoff_curve(); p <- pal(); b <- base()
      cap <- e$params$max_schedule_months
      natural <- e$natural_schedule_months
      ok   <- curve[!is.na(curve$cost) & curve$feasible, ]
      bad  <- curve[!is.na(curve$cost) & !curve$feasible, ]

      shapes <- list()
      if (natural > min(curve$schedule)) {
        shapes <- list(list(
          type = "rect", xref = "x", yref = "paper",
          x0 = min(curve$schedule), x1 = min(natural, max(curve$schedule)), y0 = 0, y1 = 1,
          fillcolor = p$primary_soft, opacity = 0.55, line = list(width = 0), layer = "below"
        ))
      }
      fig <- plot_ly() %>%
        add_trace(x = curve$schedule, y = curve$cost, type = "scatter", mode = "lines",
                  line = list(color = p$primary, width = 2.5), name = "Cost at this cap",
                  hovertemplate = "Cap %{x} months<br>%{y:$,.0f}<extra></extra>")
      if (nrow(bad) > 0) {
        fig <- fig %>% add_trace(
          x = bad$schedule, y = bad$cost, type = "scatter", mode = "markers",
          marker = list(color = p$warning, size = 8, symbol = "circle-open", line = list(width = 2)),
          name = "Needs more people than your cap",
          hovertemplate = "Cap %{x} months<br>%{y:$,.0f}<br>Not feasible with your team cap<extra></extra>")
      }
      fig %>%
        add_trace(x = cap, y = e$cost_usd, type = "scatter", mode = "markers",
                  marker = list(color = p$ink, size = 13, symbol = "diamond",
                                line = list(color = p$surface, width = 2)),
                  name = "Your cap",
                  hovertemplate = paste0("Your cap: %{x} months<br>%{y:$,.0f}<extra></extra>")) %>%
        add_annotations(
          x = natural, y = 1, xref = "x", yref = "paper", yanchor = "top", xanchor = "left",
          text = paste0("natural schedule ", fmt_months(natural)), showarrow = FALSE,
          font = list(color = p$ink_muted, size = 11), xshift = 4
        ) %>%
        layout(
          shapes = shapes,
          xaxis = c(b$xaxis, list(title = "Schedule cap (months)", dtick = 6)),
          yaxis = c(b$yaxis, list(title = "", tickprefix = "$", tickformat = "~s", rangemode = "tozero")),
          legend = c(b$legend, list(orientation = "h", x = 0, y = -0.22)),
          paper_bgcolor = b$paper_bgcolor, plot_bgcolor = b$plot_bgcolor,
          font = b$font, hoverlabel = b$hoverlabel,
          margin = list(t = 16, r = 16, b = 72, l = 56)
        ) %>% app_chart_config()
    })

    # ========================================================================
    # RANKED DRIVERS: same deltas as the waterfall, sorted by size
    # ========================================================================
    output$drivers_ranked <- renderPlotly({
      s <- steps(); p <- pal(); b <- base()
      d <- s[s$kind %in% c("multiplier", "premium") & abs(s$delta) >= 0.5, ]
      d <- d[order(abs(d$delta), decreasing = TRUE), ]
      validate(need(nrow(d) > 0, "Every driver is at its nominal level, so nothing adds or saves cost."))
      labels <- ifelse(d$delta >= 0, paste0("+", fmt_usd_short(d$delta)),
                       paste0("−", fmt_usd_short(abs(d$delta))))
      plot_ly(
        x = d$delta, y = d$name, type = "bar", orientation = "h",
        marker = list(color = ifelse(d$delta >= 0, p$increase, p$decrease)),
        text = labels, textposition = "outside", cliponaxis = FALSE,
        textfont = list(color = p$ink, size = 12),
        hovertemplate = "%{y}<br>%{x:$,.0f}<extra></extra>"
      ) %>%
        layout(
          xaxis = c(b$xaxis, list(title = "Cost added (right) or saved (left)",
                                  tickprefix = "$", tickformat = "~s", zeroline = TRUE)),
          yaxis = c(b$yaxis[setdiff(names(b$yaxis), "gridcolor")],
                    list(title = "", autorange = "reversed", automargin = TRUE)),
          showlegend = FALSE, paper_bgcolor = b$paper_bgcolor, plot_bgcolor = b$plot_bgcolor,
          font = b$font, hoverlabel = b$hoverlabel,
          margin = list(t = 12, r = 72, b = 56, l = 12)
        ) %>% app_chart_config()
    })

    # ========================================================================
    # LANGUAGES: sorted bars, one hue, grey for not billed
    # ========================================================================
    output$lang_bars <- renderPlotly({
      bd <- billable_data(); p <- pal(); b <- base()
      df <- bd$lang_df[bd$lang_df$Code > 0, , drop = FALSE]
      df <- df[order(-df$Billable, -df$Code), , drop = FALSE]
      share <- ifelse(df$Billable, df$Code / max(bd$billable_code, 1), NA)
      labels <- ifelse(df$Billable,
                       sprintf("%s · %.0f%%", fmt_int(df$Code), 100 * share),
                       sprintf("%s · not billed", fmt_int(df$Code)))
      plot_ly(
        x = df$Code, y = df$Language, type = "bar", orientation = "h",
        marker = list(color = ifelse(df$Billable, p$primary, p$context)),
        text = labels, textposition = "outside", cliponaxis = FALSE,
        textfont = list(color = p$ink, size = 12),
        hovertemplate = "%{y}<br>%{x:,} lines<extra></extra>"
      ) %>%
        layout(
          xaxis = c(b$xaxis, list(title = "Lines of code", tickformat = "~s")),
          yaxis = c(b$yaxis[setdiff(names(b$yaxis), "gridcolor")],
                    list(title = "", autorange = "reversed", automargin = TRUE)),
          showlegend = FALSE, paper_bgcolor = b$paper_bgcolor, plot_bgcolor = b$plot_bgcolor,
          font = b$font, hoverlabel = b$hoverlabel,
          margin = list(t = 12, r = 110, b = 48, l = 12)
        ) %>% app_chart_config()
    })

    # ========================================================================
    # SENSITIVITY: categorical colours for complexity, ink marker for you
    # ========================================================================
    output$sensitivity <- renderPlotly({
      bd <- billable_data(); pr <- params(); e <- est(); p <- pal(); b <- base()
      grid <- expand.grid(team = 1:5, complexity = c("low", "medium", "high"),
                          stringsAsFactors = FALSE)
      grid$cost <- mapply(function(t, c) {
        run_estimate(bd, pr, overrides = list(complexity = c, team_experience = t,
                                              maintenance_rate = 0, maintenance_years = 0))$cost_usd
      }, grid$team, grid$complexity)
      cols <- c(low = p$cat[1], medium = p$cat[2], high = p$cat[4])
      fig <- plot_ly()
      for (c in c("low", "medium", "high")) {
        g <- grid[grid$complexity == c, ]
        fig <- fig %>% add_trace(
          x = g$team, y = g$cost, type = "scatter", mode = "lines+markers",
          name = paste(tools::toTitleCase(c), "complexity"),
          line = list(color = cols[[c]], width = if (c == pr$complexity) 3 else 1.5),
          marker = list(color = cols[[c]], size = 6),
          hovertemplate = paste0(tools::toTitleCase(c), " complexity<br>Team experience %{x}<br>%{y:$,.0f}<extra></extra>"))
      }
      fig %>%
        add_trace(x = pr$team_exp, y = e$cost_usd, type = "scatter", mode = "markers",
                  marker = list(color = p$ink, size = 13, symbol = "diamond",
                                line = list(color = p$surface, width = 2)),
                  name = "Your estimate",
                  hovertemplate = "Your estimate<br>%{y:$,.0f}<extra></extra>") %>%
        layout(
          xaxis = c(b$xaxis, list(title = "Team experience (1 novice to 5 expert)", dtick = 1)),
          yaxis = c(b$yaxis, list(title = "", tickprefix = "$", tickformat = "~s", rangemode = "tozero")),
          legend = c(b$legend, list(orientation = "h", x = 0, y = -0.22)),
          paper_bgcolor = b$paper_bgcolor, plot_bgcolor = b$plot_bgcolor,
          font = b$font, hoverlabel = b$hoverlabel,
          margin = list(t = 16, r = 16, b = 72, l = 56)
        ) %>% app_chart_config()
    })

    # ========================================================================
    # MAINTENANCE AND TCO
    # ========================================================================
    output$maintenance_ui <- renderUI({
      e <- est()
      if (is.null(e$maintenance)) {
        return(state_panel(
          "could_not_run", "Maintenance is switched off",
          "Set Maintenance years above 0 in the sidebar to project yearly upkeep and the total cost of ownership. Typical upkeep is 15 to 25% of the build cost each year."
        ))
      }
      m <- e$maintenance
      tagList(
        tags$div(
          class = "hero-kpis mb-3",
          kpi_tile("Build cost", fmt_usd(e$cost_usd),
                   reference = "One-off", n_text = fmt_months(e$final_schedule_months)),
          kpi_tile(sprintf("Maintenance over %d years", m$maintenance_years),
                   fmt_usd(m$total_maintenance_pv),
                   reference = sprintf("%s nominal", fmt_usd(m$total_maintenance_nominal)),
                   n_text = sprintf("%.0f%% of build per year, +5%%/yr, discounted at %.0f%%",
                                    m$maintenance_rate * 100, m$discount_rate * 100)),
          kpi_tile("Total cost of ownership", fmt_usd(m$tco),
                   reference = "Build + maintenance in today's dollars",
                   n_text = sprintf("%.1f× the build cost", m$tco / e$cost_usd))
        ),
        tags$div(
          class = "section-grid",
          chart_card("Cumulative cost over time",
                     "Nominal dollars and today's dollars; the gap is the discount",
                     plotlyOutput(ns("maintenance_chart"), height = "300px")),
          chart_card("Total cost of ownership at other maintenance rates",
                     "Today's dollars; the darker bar is your rate",
                     plotlyOutput(ns("maint_rate_chart"), height = "300px"))
        )
      )
    })

    output$maintenance_chart <- renderPlotly({
      e <- est(); req(e$maintenance); m <- e$maintenance; p <- pal(); b <- base()
      years   <- 0:m$maintenance_years
      nominal <- c(0, cumsum(m$yearly_costs)) + e$cost_usd
      pv      <- c(0, cumsum(m$yearly_costs / (1 + m$discount_rate)^seq_along(m$yearly_costs))) + e$cost_usd
      plot_ly() %>%
        add_trace(x = years, y = nominal, type = "scatter", mode = "lines+markers",
                  line = list(color = p$context, width = 2, dash = "dot"),
                  marker = list(color = p$context, size = 6), name = "Nominal",
                  hovertemplate = "Year %{x}<br>Nominal %{y:$,.0f}<extra></extra>") %>%
        add_trace(x = years, y = pv, type = "scatter", mode = "lines+markers",
                  line = list(color = p$primary, width = 2.5),
                  marker = list(color = p$primary, size = 7), name = "Today's dollars",
                  hovertemplate = "Year %{x}<br>Today's dollars %{y:$,.0f}<extra></extra>") %>%
        add_annotations(x = 0, y = e$cost_usd, text = "build", showarrow = FALSE,
                        xanchor = "left", yanchor = "bottom", xshift = 6,
                        font = list(color = p$ink_muted, size = 11)) %>%
        layout(
          xaxis = c(b$xaxis, list(title = "Years after launch", dtick = 1)),
          yaxis = c(b$yaxis, list(title = "", tickprefix = "$", tickformat = "~s", rangemode = "tozero")),
          legend = c(b$legend, list(orientation = "h", x = 0, y = -0.25)),
          paper_bgcolor = b$paper_bgcolor, plot_bgcolor = b$plot_bgcolor,
          font = b$font, hoverlabel = b$hoverlabel,
          margin = list(t = 12, r = 16, b = 64, l = 56)
        ) %>% app_chart_config()
    })

    output$maint_rate_chart <- renderPlotly({
      e <- est(); req(e$maintenance); bd <- billable_data(); pr <- params(); p <- pal(); b <- base()
      rates <- seq(0.10, 0.40, by = 0.05)
      tcos  <- sapply(rates, function(r) {
        tryCatch({
          r_est <- run_estimate(bd, pr, overrides = list(
            maintenance_rate = r, maintenance_years = e$maintenance$maintenance_years))
          if (!is.null(r_est$maintenance)) r_est$maintenance$tco else NA_real_
        }, error = function(err) NA_real_)
      })
      is_cur <- abs(rates - e$params$maintenance_rate) < 0.001
      plot_ly(
        x = paste0(rates * 100, "%"), y = tcos, type = "bar",
        marker = list(color = ifelse(is_cur, p$primary, p$context)),
        text = fmt_usd_short(tcos), textposition = "outside", cliponaxis = FALSE,
        textfont = list(color = p$ink, size = 11),
        hovertemplate = "Rate %{x}<br>TCO %{y:$,.0f}<extra></extra>"
      ) %>%
        layout(
          xaxis = c(b$xaxis, list(title = "Annual maintenance rate")),
          yaxis = c(b$yaxis, list(title = "", tickprefix = "$", tickformat = "~s", rangemode = "tozero")),
          showlegend = FALSE, paper_bgcolor = b$paper_bgcolor, plot_bgcolor = b$plot_bgcolor,
          font = b$font, hoverlabel = b$hoverlabel,
          margin = list(t = 24, r = 16, b = 48, l = 56)
        ) %>% app_chart_config()
    })

    # ========================================================================
    # ASSUMPTIONS: table and text report
    # ========================================================================
    output$details_table <- renderDT({
      e <- est(); bd <- billable_data(); p <- e$params
      lang <- bd$lang_df
      rows <- data.frame(
        Item = c(
          paste0("Lines of ", lang$Language, if (any(!lang$Billable)) ifelse(lang$Billable, "", " (not billed)") else ""),
          "Billable lines", "Complexity", "Team experience", "Code reuse", "Tooling",
          "Cost per developer-year", "Team cap", "Schedule cap",
          "Reliability", "Product complexity", "Required reusability", "Team continuity",
          "Domain experience", "Maintenance rate", "Maintenance years",
          "Effort", "Schedule", "Team", "Estimated cost", "Estimate range"
        ),
        Value = c(
          fmt_int(lang$Code),
          fmt_int(bd$billable_code), tools::toTitleCase(p$complexity),
          paste0(p$team_experience, " (", team_exp_word(p$team_experience), ")"),
          sprintf("%.2f", p$reuse_factor), sprintf("%.2f", p$tool_support),
          fmt_usd(p$avg_wage, exact = TRUE), paste(p$max_team_size, "people"), fmt_months(p$max_schedule_months),
          sprintf("%.2f", p$rely), sprintf("%.2f", p$cplx), sprintf("%.2f", p$ruse),
          sprintf("%.2f", p$pcon), sprintf("%.2f", p$apex),
          sprintf("%.0f%%", p$maintenance_rate * 100), as.character(p$maintenance_years),
          paste(format(round(e$effort_person_months, 1), nsmall = 1), "person-months"),
          fmt_months(e$final_schedule_months), fmt_fte(e$final_people),
          fmt_usd(e$cost_usd),
          paste(fmt_usd(e$estimate_range$low), "to", fmt_usd(e$estimate_range$high))
        ),
        stringsAsFactors = FALSE
      )
      datatable(rows, rownames = FALSE, class = "compact stripe",
                options = list(dom = "t", paging = FALSE, ordering = FALSE,
                               columnDefs = list(list(className = "num", targets = 1))))
    })

    output$estimate_text <- renderText({
      e <- est(); bd <- billable_data(); s <- steps(); st <- estimate_status(e)
      lines <- c(
        "COST ESTIMATE",
        sprintf("Billable lines:     %s", fmt_int(bd$billable_code)),
        if (bd$has_docs) sprintf("Excluded doc/config: %s", fmt_int(bd$total_code - bd$billable_code)),
        sprintf("Estimated cost:     %s", fmt_usd(e$cost_usd)),
        sprintf("Estimate range:     %s to %s (±30%%)", fmt_usd(e$estimate_range$low), fmt_usd(e$estimate_range$high)),
        sprintf("Schedule:           %s", fmt_months(e$final_schedule_months)),
        sprintf("Team:               %s", fmt_fte(e$final_people)),
        sprintf("Effort:             %s person-months", format(round(e$effort_person_months, 1), nsmall = 1)),
        sprintf("Status:             %s", st$word),
        "",
        "HOW THE COST IS BUILT",
        sprintf("  %-24s %s", s$name, ifelse(s$kind %in% c("base", "total"), fmt_usd(s$delta),
                                             ifelse(s$delta >= 0, paste0("+", fmt_usd(s$delta)),
                                                    paste0("-", fmt_usd(abs(s$delta))))))
      )
      if (!is.null(e$maintenance)) {
        m <- e$maintenance
        lines <- c(lines, "",
          "MAINTENANCE AND TCO",
          sprintf("Annual maintenance: %s (%.0f%% of build, +5%%/yr)", fmt_usd(m$annual_maintenance), m$maintenance_rate * 100),
          sprintf("Over %d years:       %s nominal, %s in today's dollars (%.0f%%/yr)",
                  m$maintenance_years, fmt_usd(m$total_maintenance_nominal), fmt_usd(m$total_maintenance_pv), m$discount_rate * 100),
          sprintf("Total cost of ownership: %s", fmt_usd(m$tco)))
      }
      paste(lines, collapse = "\n")
    })

    # ========================================================================
    # PLAN ADVISOR
    # ========================================================================
    num_fact <- function(x, lo, hi) {
      v <- suppressWarnings(as.numeric(x))
      if (length(v) != 1 || is.na(v) || !is.finite(v) || v < lo || v > hi) NULL else v
    }
    know <- reactive(list(
      people = num_fact(input$know_people, 1, 8),
      months = num_fact(input$know_months, 1, 60),
      budget = num_fact(input$know_budget, 1000, 1e9)
    ))
    advice <- reactive({
      req(has_data())
      plan_advice(billable_data(), params(), know())
    })

    output$plan_advice_ui <- renderUI({
      a <- advice()
      tags$p(class = "plan-advice", role = "status", paste(a$narrative, collapse = " "))
    })

    plan_card <- function(pl) {
      st_kind <- if (!pl$feasible) "action" else if (pl$premium > 1) "watch" else "ok"
      note <- if (!is.null(pl$note)) pl$note else if (pl$premium > 1)
        sprintf("+%d%% rush premium", round((pl$premium - 1) * 100)) else "No rush premium"
      if (isTRUE(pl$coordination)) note <- paste(note, "\u00b7 +10% coordination")
      tags$div(
        class = "plan-card",
        kpi_tile(pl$label, fmt_usd(pl$cost),
                 reference = paste(fmt_months(pl$months), "\u00b7", fmt_fte(pl$people)),
                 n_text = sprintf("Team cap %d \u00b7 schedule cap %s", pl$k, fmt_months(pl$cap)),
                 status = st_kind,
                 status_label = if (st_kind == "ok") "Within plan" else if (st_kind == "watch") "Compressed" else "Not feasible",
                 note = note),
        tags$div(
          class = "plan-card-actions",
          if (isTRUE(pl$applicable))
            actionButton(ns(paste0("apply_", pl$key)), "Apply", class = "btn-primary btn-sm", icon = icon("sliders"))
          else
            tags$button(type = "button", class = "btn btn-outline-secondary btn-sm", disabled = NA,
                        title = sprintf("Longer than the %d-month cap the sidebar allows", max(PLAN_CAPS)), "Apply"),
          actionButton(ns(paste0("save_", pl$key)), "Save as scenario", class = "btn-outline-secondary btn-sm")
        )
      )
    }

    output$plan_cards <- renderUI({
      a <- advice(); rec <- a$recommendations
      if (isTRUE(a$grid$zero)) return(NULL)
      cards <- lapply(rec$plans, plan_card)
      if (!is.null(rec$unmet$deadline)) {
        u <- rec$unmet$deadline
        cards <- c(cards, list(tags$div(class = "plan-card",
          state_panel("could_not_run", sprintf("%s cannot be met", fmt_months(u$deadline)),
                      sprintf("The practical floor is %s with up to 8 people. The nearest plan is %s with %s at %s.",
                              fmt_months(u$floor), fmt_months(u$nearest$months), fmt_fte(u$nearest$people), fmt_usd(u$nearest$cost)),
                      action = actionButton(ns("apply_nearest"), "Apply the nearest plan", class = "btn-outline-secondary btn-sm")))))
      }
      if (!is.null(rec$unmet$budget)) {
        u <- rec$unmet$budget
        lever_txt <- vapply(u$levers, function(l) sprintf("%s from %s to %s saves %s", l$lever, tolower(l$from), tolower(l$to), fmt_usd(l$saving)), character(1))
        cards <- c(cards, list(tags$div(class = "plan-card",
          state_panel("could_not_run", sprintf("No plan fits %s", fmt_usd(u$budget, exact = TRUE)),
                      paste0("The cheapest is ", fmt_usd(u$cheapest_cost), ". About ", round(100 * u$scope$share), "% of the scope (",
                             fmt_int(u$scope$lines), " lines) would fit",
                             if (length(lever_txt)) paste0("; ", paste(lever_txt, collapse = "; ")) else "", ".")))))
      }
      tags$div(class = "plan-cards", cards)
    })

    output$staffing_chart <- renderPlotly({
      a <- advice(); cv <- a$curve; p <- pal(); b <- base()
      validate(need(nrow(cv) > 0, "Nothing to plan yet."))
      kn <- a$know
      mark_k <- if (!is.null(kn$people)) kn$people else min(8, max(1, round(a$grid$nominal_people)))
      shapes <- list(
        list(type = "rect", xref = "x", yref = "paper", x0 = 5.5, x1 = 8.5, y0 = 0, y1 = 1,
             fillcolor = p$warning, opacity = 0.08, line = list(width = 0), layer = "below"),
        list(type = "line", xref = "paper", yref = "y", x0 = 0, x1 = 1, y0 = a$floor_months, y1 = a$floor_months,
             line = list(color = p$ink_muted, dash = "dash", width = 1.5))
      )
      fig <- plot_ly() %>%
        add_trace(x = cv$k, y = cv$natural_months, type = "scatter", mode = "lines+markers",
                  line = list(color = p$context, width = 2, dash = "dot"), marker = list(color = p$context, size = 6),
                  name = "No rush: natural schedule",
                  hovertemplate = "%{x} people<br>%{y:.1f} months, no premium<extra></extra>") %>%
        add_trace(x = cv$k, y = cv$months, type = "scatter", mode = "lines+markers+text",
                  line = list(color = p$primary, width = 2.5), marker = list(color = p$primary, size = 8),
                  text = fmt_usd_short(cv$cost), textposition = "top center", textfont = list(color = p$ink, size = 11),
                  name = "Fastest practical",
                  hovertemplate = "%{x} people<br>%{y:.1f} months<br>%{text}<extra></extra>")
      mk <- cv[cv$k == mark_k, ]
      if (nrow(mk) == 1 && !is.na(mk$months)) {
        fig <- fig %>% add_trace(x = mk$k, y = mk$months, type = "scatter", mode = "markers",
                                 marker = list(color = p$ink, size = 13, symbol = "diamond", line = list(color = p$surface, width = 2)),
                                 name = if (!is.null(kn$people)) "Your team" else "Suggested team",
                                 hovertemplate = "%{x} people<br>%{y:.1f} months<extra></extra>")
      }
      fig %>%
        add_annotations(x = 1, y = a$floor_months, xref = "x", yref = "y", xanchor = "left", yanchor = "bottom",
                        text = paste0("practical floor ", fmt_months(a$floor_months)), showarrow = FALSE,
                        font = list(color = p$ink_muted, size = 11)) %>%
        add_annotations(x = 7, y = 1, xref = "x", yref = "paper", yanchor = "top",
                        text = "coordination overhead", showarrow = FALSE, font = list(color = p$warning_text, size = 11)) %>%
        layout(
          shapes = shapes,
          xaxis = c(b$xaxis, list(title = "Team size (people)", dtick = 1, range = c(0.5, 8.5))),
          yaxis = c(b$yaxis, list(title = "Months to deliver", rangemode = "tozero")),
          legend = c(b$legend, list(orientation = "h", x = 0, y = -0.22)),
          paper_bgcolor = b$paper_bgcolor, plot_bgcolor = b$plot_bgcolor,
          font = b$font, hoverlabel = b$hoverlabel,
          margin = list(t = 24, r = 16, b = 72, l = 56)
        ) %>% app_chart_config()
    })

    # Apply / save handles: one observer per plan key, registered once
    apply_plan_val <- reactiveVal(NULL)
    save_plan_val  <- reactiveVal(NULL)
    plan_by_key <- function(key) {
      rec <- advice()$recommendations
      if (key == "nearest") return(rec$unmet$deadline$nearest)
      rec$plans[[key]]
    }
    for (key in c("team", "deadline", "budget", "cheapest", "fastest", "nearest")) local({
      k <- key
      observeEvent(input[[paste0("apply_", k)]], {
        pl <- plan_by_key(k); req(pl)
        apply_plan_val(list(max_team = pl$k, max_schedule = pl$cap, label = pl$label, nonce = runif(1)))
      }, ignoreInit = TRUE)
      observeEvent(input[[paste0("save_", k)]], {
        pl <- plan_by_key(k); req(pl)
        snap <- snapshot()
        snap$params$max_team <- pl$k
        snap$params$max_schedule <- pl$cap
        snap$label <- paste0(snap$label, " \u00b7 ", pl$label)
        snap$est <- run_estimate(billable_data(), snap$params)
        snap$nonce <- runif(1)
        save_plan_val(snap)
      }, ignoreInit = TRUE)
    })

    # ========================================================================
    # SUMMARY STRIP (shown by app.js only when the hero is off screen)
    # ========================================================================
    output$summary_strip <- renderUI({
      req(has_data())
      e <- est(); st <- estimate_status(e)
      tags$div(
        class = "summary-strip", role = "region", `aria-label` = "Estimate summary",
        tags$div(class = "strip-item", tags$span(class = "strip-label", "Cost"),
                 tags$span(class = "strip-value", fmt_usd(e$cost_usd))),
        tags$div(class = "strip-item strip-secondary", tags$span(class = "strip-label", "Range"),
                 tags$span(class = "strip-value",
                           paste(fmt_usd_short(e$estimate_range$low), "to", fmt_usd_short(e$estimate_range$high)))),
        tags$div(class = "strip-item", tags$span(class = "strip-label", "Schedule"),
                 tags$span(class = "strip-value", fmt_months(e$final_schedule_months))),
        tags$div(class = "strip-item strip-secondary", tags$span(class = "strip-label", "Team"),
                 tags$span(class = "strip-value", fmt_fte(e$final_people))),
        if (st$kind != "ok")
          tags$div(class = "strip-item strip-secondary",
                   tags$span(class = "strip-warning",
                             icon("triangle-exclamation", `aria-hidden` = "true"), st$word)),
        tags$div(
          class = "strip-actions",
          if (pdf_available)
            tags$button(type = "button", class = "btn btn-primary btn-sm",
                        onclick = sprintf("document.getElementById(%s).click()",
                                          jsonlite::toJSON(ns("download_pdf"), auto_unbox = TRUE)),
                        icon("file-pdf", `aria-hidden` = "true"), " PDF"),
          tags$button(type = "button", class = "btn btn-outline-secondary btn-sm",
                      onclick = "window.scrollTo({top: 0, behavior: 'smooth'})",
                      "Back to top")
        )
      )
    })

    # ========================================================================
    # DOWNLOADS
    # ========================================================================
    output$download_pdf <- pdf_download_handler(function() {
      d <- analysis_data()
      build_report_payload(
        est          = est(),
        billable     = billable_data(),
        curve        = tradeoff_curve(),
        project_name = if (!is.null(d$source_label)) d$source_label else "Your project",
        steps        = steps(),
        plan         = advice()
      )
    })

    output$download_csv <- downloadHandler(
      filename = function() sprintf("cost-estimate-%s.csv", format(Sys.Date(), "%Y%m%d")),
      content = function(file) {
        e <- est(); bd <- billable_data(); s <- steps()
        lang <- bd$lang_df
        out <- rbind(
          data.frame(section = "language", item = lang$Language,
                     value = lang$Code, note = ifelse(lang$Billable, "billable", "not billed"),
                     stringsAsFactors = FALSE),
          data.frame(section = "cost_step", item = s$name, value = round(s$delta), note = s$kind,
                     stringsAsFactors = FALSE),
          data.frame(section = "result",
                     item = c("cost_usd", "range_low", "range_high", "schedule_months", "team_fte", "effort_person_months"),
                     value = c(e$cost_usd, e$estimate_range$low, e$estimate_range$high,
                               e$final_schedule_months, e$final_people, e$effort_person_months),
                     note = "", stringsAsFactors = FALSE)
        )
        write.csv(out, file, row.names = FALSE)
      }
    )

    output$download_json <- downloadHandler(
      filename = function() sprintf("cost-estimate-%s.json", format(Sys.Date(), "%Y%m%d")),
      content = function(file) {
        e <- est(); bd <- billable_data(); d <- analysis_data()
        payload <- list(
          app_version   = if (exists("APP_VERSION")) APP_VERSION else "2.1.0",
          generated_on  = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
          source        = d$source_label,
          language_mix  = bd$language_mix,
          inputs        = e$params,
          estimate      = e[setdiff(names(e), "params")],
          cost_steps    = steps(),
          display       = list(cost = fmt_usd(e$cost_usd),
                               range = paste(fmt_usd(e$estimate_range$low), "to", fmt_usd(e$estimate_range$high)),
                               schedule = fmt_months(e$final_schedule_months),
                               team = fmt_fte(e$final_people),
                               status = estimate_status(e)$word)
        )
        jsonlite::write_json(payload, file, pretty = TRUE, auto_unbox = TRUE, digits = NA)
      }
    )

    # ========================================================================
    # HANDLES FOR THE APP
    # ========================================================================
    snapshot <- reactive({
      req(has_data())
      d <- analysis_data()
      list(label = d$source_label, language_mix = billable_data()$language_mix,
           params = params(), est = est(), know = know())
    })

    list(
      est            = est,
      billable_data  = billable_data,
      tradeoff_curve = tradeoff_curve,
      steps          = steps,
      snapshot       = snapshot,
      run_example    = reactive(input$run_example),
      save_scenario  = reactive(input$save_scenario),
      apply_plan     = reactive(apply_plan_val()),
      save_plan      = reactive(save_plan_val()),
      advice         = advice
    )
  })
}
