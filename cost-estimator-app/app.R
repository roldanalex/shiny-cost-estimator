# Software Cost Estimator - client-facing COCOMO II cost, schedule and TCO
# estimator for any software project (built for R Shiny and data-science teams first)
# Author: Alexis Roldan
#
# Interaction model: line counts, ZIP uploads and folder scans need "Run
# estimate"; every other parameter recalculates the estimate live.

library(shiny)
library(bslib)
library(plotly)
library(DT)
library(markdown)

# Referenced so rsconnect bundles the PDF-report toolchain (used from
# report/estimate_report.qmd, which rsconnect's scanner doesn't parse)
requireNamespace("quarto", quietly = TRUE)
requireNamespace("ragg", quietly = TRUE)
requireNamespace("knitr", quietly = TRUE)

APP_VERSION  <- "2.2.0"
APP_NAME     <- "Software Cost Estimator"
APP_OWNER    <- "Alexis Roldan"
APP_REPO_URL <- "https://github.com/roldanalex/shiny-app-valuation"

# Allow ZIP uploads up to the advertised 50MB limit
options(shiny.maxRequestSize = 50 * 1024^2)

# Source estimation functions (prefer R/ originals, fall back to modules/)
if (file.exists("../R/shiny_cost_estimator.R")) {
  source("../R/shiny_cost_estimator.R")
} else {
  source("modules/shiny_cost_estimator.R")
}
if (file.exists("../R/repo_code_analyzer.R")) {
  source("../R/repo_code_analyzer.R")
} else {
  source("modules/repo_code_analyzer.R")
}

# Design tokens, pure helpers, UI builders and modules
source("modules/theme.R")
source("modules/app_helpers.R")
source("modules/ui_helpers.R")
source("modules/pdf_report.R")
source("modules/analysis_module.R")
source("modules/plan_helpers.R")
source("modules/comparison_module.R")

# Detect deployed environment (shinyapps.io sets R_CONFIG_ACTIVE="rsconnect")
is_deployed <- nzchar(Sys.getenv("R_CONFIG_ACTIVE"))

# ============================================================================
# HELP COPY (shown in popovers next to each field)
# ============================================================================

help_content <- list(
  complexity = list(
    title = "Complexity",
    body = tagList(
      p("How architecturally involved the project is, whatever the language."),
      tags$ul(
        tags$li(tags$b("Low:"), " a small tool or service: a few screens or endpoints, basic forms, straightforward logic."),
        tags$li(tags$b("Medium:"), " several interconnected features, moderate data processing, some integrations."),
        tags$li(tags$b("High:"), " complex architecture, AI/ML parts, real-time or distributed processing, many interacting modules.")
      ),
      p("When in doubt, choose Medium. Higher complexity grows effort exponentially with size.")
    )
  ),
  framework = list(
    title = "What kind of code?",
    body = tagList(
      p("COCOMO II was calibrated on systems and enterprise code. This tool applies a documented 0.85 calibration for projects built on modern frameworks and high-level languages (R, Python, JavaScript, web and data stacks), where a line of code does more."),
      p("Choose ", tags$b("Systems, embedded or legacy code"), " for C, C++, Java, firmware or large legacy systems: the discount is removed and the published constant applies. The waterfall shows this step as 'Framework calibration'.")
    )
  ),
  team = list(
    title = "Team experience",
    body = tagList(
      p("Average skill of the people who will build it, 1 to 5."),
      tags$ul(
        tags$li(tags$b("1 Novice:"), " new to the language, framework and domain."),
        tags$li(tags$b("3 Competent:"), " works independently on most tasks."),
        tags$li(tags$b("4 Proficient:"), " experienced; this is the baseline."),
        tags$li(tags$b("5 Expert:"), " deep expertise, fast and clean.")
      ),
      p("More experience lowers the estimate.")
    )
  ),
  reuse = list(
    title = "Code reuse",
    body = tagList(
      p("How much existing code, packages or templates the team can reuse."),
      p("More reuse means less new code to write, so a lower estimate. This is different from ",
        tags$em("required reusability"), " (an advanced driver), which is the extra effort to make ",
        tags$em("this"), " code reusable by others.")
    )
  ),
  tools = list(
    title = "Tooling and process",
    body = tagList(
      p("How good the development environment and process are: IDE, version control, CI/CD, automated tests, code review."),
      p("Better tooling means faster delivery and a lower estimate.")
    )
  ),
  wage = list(
    title = "Cost per developer-year",
    body = tagList(
      p("The fully loaded annual cost of one developer in US dollars (salary plus benefits and overhead). It converts person-months of effort into money."),
      p("If you only know base salary, $105,000 is a reasonable US average for software and data roles. Doubling the wage doubles the estimate.")
    )
  ),
  maxteam = list(
    title = "Team cap",
    body = tagList(
      p("The most people you can put on the project at once."),
      p("A smaller team means a longer schedule. Teams of 6 or more carry a 10% coordination premium. The model never uses more than 8 people, because beyond that coordination costs outweigh the gain.")
    )
  ),
  maxsched = list(
    title = "Schedule cap",
    body = tagList(
      p("The longest the project may take, in months."),
      p("If the natural schedule is longer, the timeline is compressed and the cost rises smoothly (COCOMO II's schedule-compression driver), up to double. Halving the natural schedule adds roughly 40%."),
      p("If a compressed plan would need more people than your team cap, the app says the plan is not feasible.")
    )
  ),
  rely = list(
    title = "Required reliability",
    body = tagList(
      p("How much a failure would cost: from a prototype where failures hardly matter, to a mission-critical system."),
      p("Higher reliability needs more testing, review and defensive code.")
    )
  ),
  cplx = list(
    title = "Product complexity",
    body = tagList(
      p("The algorithmic and computational complexity of what the software does, independent of its size."),
      p("Simple CRUD sits at the low end; machine learning, real-time or distributed processing at the high end.")
    )
  ),
  ruse = list(
    title = "Required reusability",
    body = tagList(
      p("How much of the work goes into making components usable by other projects: documentation, generalisation, extra testing."),
      p("Not the same as code reuse, which is how much existing code you can lean on.")
    )
  ),
  pcon = list(
    title = "Team continuity",
    body = tagList(
      p("How stable the team is over the project. Turnover costs effort in onboarding and lost knowledge.")
    )
  ),
  apex = list(
    title = "Domain experience",
    body = tagList(
      p("How familiar the team is with this kind of application, as opposed to general skill. A senior developer can still be new to finance or bioinformatics.")
    )
  ),
  maint_rate = list(
    title = "Annual maintenance rate",
    body = tagList(
      p("Yearly maintenance (bug fixes, updates, small enhancements) as a share of the build cost."),
      tags$ul(
        tags$li(tags$b("15-20%:"), " typical applications."),
        tags$li(tags$b("25-30%:"), " frequent change requests or regulatory updates."),
        tags$li(tags$b("35-40%:"), " legacy systems or fast-moving domains.")
      ),
      p("Costs escalate 5% a year for growing complexity and knowledge turnover.")
    )
  ),
  maint_years = list(
    title = "Maintenance years",
    body = tagList(
      p("How many years of maintenance to include in the total cost of ownership. 3 to 5 years is a typical planning horizon; set 0 to show the build cost only."),
      p("Multi-year totals are shown in today's dollars (discounted at 5% a year) and in nominal dollars.")
    )
  )
)

# ============================================================================
# SIDEBAR BUILDERS
# ============================================================================

rating_field <- function(prefix, key) {
  id <- paste0(prefix, "_", key)
  field_with_help(
    selectInput(id, label = NULL, choices = rating_choices(key),
                selected = as.character(PARAM_DEFAULTS[[key]]), width = "100%"),
    label = RATING_LEVELS[[key]]$title, input_id = id,
    help_title = help_content[[key]]$title, help_body = help_content[[key]]$body
  )
}

source_inputs <- function() {
  choices <- if (!is_deployed) {
    c("Manual" = "manual", "ZIP" = "zip", "Folder" = "local")
  } else {
    c("Manual entry" = "manual", "ZIP upload" = "zip")
  }
  tags$div(
    class = "sidebar-group",
    tags$h2(class = "sidebar-group-title", "Where is the code?"),
    tags$div(class = "segmented",
      radioButtons("input_method", label = NULL, choices = choices,
                   selected = "manual", inline = TRUE)),

    conditionalPanel(
      condition = "input.input_method == 'manual'",
      tags$p(class = "sidebar-group-sub mt-2",
             "Pick the languages, then type rough line counts. A guess is fine; refine later."),
      tags$div(class = "field",
        tags$label(class = "field-label", `for` = "manual_langs", "Languages"),
        selectizeInput("manual_langs", label = NULL, choices = MANUAL_LANGUAGES, selected = "R",
                       multiple = TRUE, width = "100%",
                       options = list(plugins = list("remove_button"), placeholder = "Add a language"))),
      uiOutput("manual_counts"),
      uiOutput("manual_error")
    ),

    conditionalPanel(
      condition = "input.input_method == 'zip'",
      tags$p(class = "sidebar-group-sub mt-2",
             "Zip the project folder and upload it. Files are counted on the server and discarded."),
      fileInput("zip_file", "Repository ZIP (max 50 MB)", accept = ".zip",
                buttonLabel = "Choose file", placeholder = "No file chosen"),
      uiOutput("zip_error")
    ),

    if (!is_deployed)
      conditionalPanel(
        condition = "input.input_method == 'local'",
        tags$p(class = "sidebar-group-sub mt-2",
               "Point at a repository on this computer."),
        textInput("local_path", "Repository path", value = getwd(),
                  placeholder = "/path/to/your/repo"),
        actionButton("browse_folder", "Browse", icon = icon("folder-open"),
                     class = "btn-outline-secondary btn-sm"),
        uiOutput("local_error")
      )
  )
}

project_inputs <- function(prefix = "analyze") {
  tagList(
    tags$div(
      class = "sidebar-group",
      tags$h2(class = "sidebar-group-title", "The project"),
      field_with_help(
        selectInput(paste0(prefix, "_complexity"), label = NULL,
                    choices = c("Low" = "low", "Medium" = "medium", "High" = "high"),
                    selected = PARAM_DEFAULTS$complexity, width = "100%"),
        label = "Complexity", input_id = paste0(prefix, "_complexity"),
        help_title = help_content$complexity$title, help_body = help_content$complexity$body
      ),
      field_with_help(
        tags$div(class = "rating-group",
          radioButtons(paste0(prefix, "_framework"), label = NULL, choices = FRAMEWORK_CHOICES,
                       selected = PARAM_DEFAULTS$framework, width = "100%")),
        label = "What kind of code?", input_id = paste0(prefix, "_framework"),
        help_title = help_content$framework$title, help_body = help_content$framework$body
      ),
      field_with_help(
        tagList(
          sliderInput(paste0(prefix, "_team_exp"), label = NULL, min = 1, max = 5,
                      value = PARAM_DEFAULTS$team_exp, step = 1, ticks = FALSE, width = "100%"),
          uiOutput(paste0(prefix, "_team_exp_word"))
        ),
        label = "Team experience", input_id = paste0(prefix, "_team_exp"),
        help_title = help_content$team$title, help_body = help_content$team$body
      ),
      rating_field(prefix, "reuse"),
      rating_field(prefix, "tools")
    ),
    tags$div(
      class = "sidebar-group",
      tags$h2(class = "sidebar-group-title", "Money and limits"),
      field_with_help(
        tagList(
          numericInput(paste0(prefix, "_wage"), label = NULL, value = PARAM_DEFAULTS$wage,
                       min = 50000, max = 300000, step = 5000, width = "100%"),
          uiOutput(paste0(prefix, "_wage_echo"))
        ),
        label = "Cost per developer-year (USD)", input_id = paste0(prefix, "_wage"),
        help_title = help_content$wage$title, help_body = help_content$wage$body
      ),
      field_with_help(
        sliderInput(paste0(prefix, "_max_team"), label = NULL, min = 1, max = 8,
                    value = PARAM_DEFAULTS$max_team, step = 1, ticks = FALSE, width = "100%",
                    post = " people"),
        label = "Team cap", input_id = paste0(prefix, "_max_team"),
        help_title = help_content$maxteam$title, help_body = help_content$maxteam$body
      ),
      field_with_help(
        sliderInput(paste0(prefix, "_max_schedule"), label = NULL, min = 3, max = 60,
                    value = PARAM_DEFAULTS$max_schedule, step = 1, ticks = FALSE, width = "100%",
                    post = " months"),
        label = "Schedule cap", input_id = paste0(prefix, "_max_schedule"),
        help_title = help_content$maxsched$title, help_body = help_content$maxsched$body
      )
    )
  )
}

advanced_inputs <- function(prefix = "analyze") {
  tagList(
    tags$details(
      class = "sidebar-adv",
      tags$summary(
        "Advanced COCOMO drivers",
        uiOutput(paste0(prefix, "_driver_badge"), inline = TRUE),
        icon("chevron-down", class = "section-chevron", `aria-hidden` = "true")
      ),
      tags$div(
        class = "adv-body",
        tags$p(class = "sidebar-group-sub",
               "Published COCOMO II.2000 cost drivers. Nominal means no effect."),
        rating_field(prefix, "rely"),
        rating_field(prefix, "cplx"),
        rating_field(prefix, "ruse"),
        rating_field(prefix, "pcon"),
        rating_field(prefix, "apex")
      )
    ),
    tags$details(
      class = "sidebar-adv", open = NA,
      tags$summary(
        "Maintenance and TCO",
        icon("chevron-down", class = "section-chevron", `aria-hidden` = "true")
      ),
      tags$div(
        class = "adv-body",
        field_with_help(
          sliderInput(paste0(prefix, "_maint_rate"), label = NULL, min = 0, max = 40,
                      value = PARAM_DEFAULTS$maintenance_rate * 100, step = 5,
                      post = "%", ticks = FALSE, width = "100%"),
          label = "Annual maintenance rate", input_id = paste0(prefix, "_maint_rate"),
          help_title = help_content$maint_rate$title, help_body = help_content$maint_rate$body
        ),
        field_with_help(
          sliderInput(paste0(prefix, "_maint_years"), label = NULL, min = 0, max = 10,
                      value = PARAM_DEFAULTS$maintenance_years, step = 1,
                      post = " yr", ticks = FALSE, width = "100%"),
          label = "Maintenance years", input_id = paste0(prefix, "_maint_years"),
          help_title = help_content$maint_years$title, help_body = help_content$maint_years$body
        )
      )
    )
  )
}

sidebar_actions <- function() {
  tags$div(
    class = "sidebar-actions",
    actionButton("reset_params", "Reset", icon = icon("rotate-left"),
                 class = "btn-outline-secondary", title = "Reset parameters to their defaults"),
    input_task_button("run_analysis", "Run estimate", icon = icon("play"),
                      label_busy = "Counting lines", class = "btn-primary btn-run")
  )
}

# ============================================================================
# UI
# ============================================================================

ui <- page_navbar(
  title = tags$span(
    `data-ux` = "header",
    tags$img(src = "favicon.svg", alt = "", `aria-hidden` = "true"),
    APP_NAME
  ),
  window_title = APP_NAME,
  id = "nav",
  theme = app_theme(),
  fillable = FALSE,
  header = tagList(
    tags$head(
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      tags$meta(name = "theme-color", content = app_palettes$light$primary),
      tags$meta(name = "description",
                content = "COCOMO II cost, schedule, team and total-cost-of-ownership estimates for any software project."),
      tags$link(rel = "icon", type = "image/svg+xml", href = "favicon.svg"),
      tags$link(rel = "stylesheet", href = "fonts.css"),
      tags$style(HTML(css_root_vars())),
      tags$link(rel = "stylesheet", href = "custom.css"),
      tags$script(src = "app.js", defer = NA)
    ),
    skip_link("#main")
  ),
  footer = app_footer(APP_VERSION, APP_OWNER,
                      support_url = paste0(APP_REPO_URL, "/issues"), name = APP_NAME),

  # ── Estimate ───────────────────────────────────────────────────────────────
  nav_panel(
    title = "Estimate", value = "estimate",
    layout_sidebar(
      fillable = FALSE,
      sidebar = sidebar(
        id = "analyze_sidebar", title = "Inputs", width = 340, open = "desktop",
        source_inputs(),
        project_inputs("analyze"),
        advanced_inputs("analyze"),
        sidebar_actions()
      ),
      tags$main(id = "main", analysisResultsUI("analyze_results"))
    )
  ),

  # ── Scenarios ──────────────────────────────────────────────────────────────
  nav_panel(
    title = "Scenarios", value = "scenarios",
    comparisonUI("compare")
  ),

  nav_spacer(),
  nav_menu(
    title = "Help", align = "right", icon = icon("circle-question"),
    nav_item(tags$a(class = "dropdown-item", href = "onboarding/index.html", target = "_blank",
                    rel = "noopener", "Getting started guide")),
    nav_item(actionLink("btn_how_to_use", "How to use", class = "dropdown-item")),
    nav_item(actionLink("btn_user_guide", "User guide", class = "dropdown-item")),
    nav_item(actionLink("btn_release_notes", "Release notes", class = "dropdown-item")),
    nav_item(tags$a(class = "dropdown-item", href = APP_REPO_URL, target = "_blank",
                    rel = "noopener", "Source on GitHub"))
  ),
  nav_item(input_dark_mode(id = "mode", mode = "light"))
)

# ============================================================================
# SERVER
# ============================================================================

server <- function(input, output, session) {

  results <- reactiveValues(analyze = NULL)
  mode    <- reactive(if (identical(input$mode, "dark")) "dark" else "light")

  # ── Help modals (long-form documentation) ─────────────────────────────────
  show_markdown_modal <- function(file, title) {
    showModal(modalDialog(
      includeMarkdown(file), title = title, size = "l", easyClose = TRUE,
      footer = modalButton("Close")
    ))
  }
  observeEvent(input$btn_how_to_use,    show_markdown_modal("markdown/app_manual.md", "How to use this app"))
  observeEvent(input$btn_user_guide,    show_markdown_modal("markdown/user_guide.md", "User guide"))
  observeEvent(input$btn_release_notes, show_markdown_modal("markdown/release_notes.md",
                                                             paste0("Release notes - v", APP_VERSION)))

  # ── Live echoes next to inputs ────────────────────────────────────────────
  output$analyze_team_exp_word <- renderUI({
    n <- input$analyze_team_exp
    req(n)
    tags$div(class = "field-hint", paste0(n, " of 5: ", team_exp_word(n)))
  })
  output$analyze_wage_echo <- renderUI({
    w <- suppressWarnings(as.numeric(input$analyze_wage))
    if (is.na(w) || !is.finite(w) || w <= 0) {
      tags$div(class = "field-error", icon("circle-exclamation", `aria-hidden` = "true"),
               "Enter a yearly cost between $50,000 and $300,000.")
    } else {
      tags$div(class = "wage-echo", paste(fmt_usd(w, exact = TRUE), "per developer-year,",
                                           fmt_usd(w / 12, exact = TRUE), "per person-month"))
    }
  })
  output$analyze_driver_badge <- renderUI({
    vals <- vapply(c("rely", "cplx", "ruse", "pcon", "apex"), function(k) {
      v <- suppressWarnings(as.numeric(input[[paste0("analyze_", k)]]))
      if (length(v) != 1 || is.na(v)) 1 else v
    }, numeric(1))
    em  <- prod(vals)
    cls <- if (abs(em - 1) < 0.005) "driver-badge"
           else if (em < 1) "driver-badge is-decrease" else "driver-badge is-increase"
    tags$span(class = cls, `aria-label` = sprintf("Combined driver effect %.2f times", em),
              sprintf("×%.2f", em))
  })

  # ── Parameters (live) ─────────────────────────────────────────────────────
  num_or <- function(x, default) {
    v <- suppressWarnings(as.numeric(x))
    if (length(v) != 1 || is.na(v) || !is.finite(v)) default else v
  }
  analyze_params <- reactive({
    list(
      complexity        = if (!is.null(input$analyze_complexity)) input$analyze_complexity else PARAM_DEFAULTS$complexity,
      team_exp          = num_or(input$analyze_team_exp, PARAM_DEFAULTS$team_exp),
      reuse             = num_or(input$analyze_reuse, PARAM_DEFAULTS$reuse),
      tools             = num_or(input$analyze_tools, PARAM_DEFAULTS$tools),
      wage              = {
        w <- num_or(input$analyze_wage, PARAM_DEFAULTS$wage)
        if (w < 50000 || w > 300000) PARAM_DEFAULTS$wage else w
      },
      max_team          = num_or(input$analyze_max_team, PARAM_DEFAULTS$max_team),
      max_schedule      = num_or(input$analyze_max_schedule, PARAM_DEFAULTS$max_schedule),
      rely              = num_or(input$analyze_rely, PARAM_DEFAULTS$rely),
      cplx              = num_or(input$analyze_cplx, PARAM_DEFAULTS$cplx),
      ruse              = num_or(input$analyze_ruse, PARAM_DEFAULTS$ruse),
      pcon              = num_or(input$analyze_pcon, PARAM_DEFAULTS$pcon),
      apex              = num_or(input$analyze_apex, PARAM_DEFAULTS$apex),
      maintenance_rate  = num_or(input$analyze_maint_rate, PARAM_DEFAULTS$maintenance_rate * 100) / 100,
      maintenance_years = num_or(input$analyze_maint_years, PARAM_DEFAULTS$maintenance_years),
      framework         = if (!is.null(input$analyze_framework) && input$analyze_framework %in% c("modern", "systems"))
                            input$analyze_framework else PARAM_DEFAULTS$framework
    )
  })

  # ── Manual entry: one count box per chosen language, values kept per session ──
  manual_store <- reactiveValues()
  manual_id <- function(lang) paste0("manual_", lang_slug(lang))
  output$manual_counts <- renderUI({
    langs <- input$manual_langs
    if (length(langs) == 0) {
      return(tags$p(class = "field-hint", "Add at least one language above."))
    }
    boxes <- lapply(langs, function(lang) {
      stored <- isolate(manual_store[[lang]])
      val <- if (!is.null(stored)) stored else if (identical(lang, "R")) EXAMPLE_MIX$R else 0
      numericInput(manual_id(lang), lang, value = val, min = 0, step = 100)
    })
    tags$div(class = "counts-grid", boxes)
  })
  lapply(MANUAL_LANGUAGES, function(lang) {
    observeEvent(input[[manual_id(lang)]], {
      manual_store[[lang]] <- input[[manual_id(lang)]]
      errors$manual <- NULL
    }, ignoreInit = TRUE)
  })
  current_manual_mix <- function() {
    langs <- input$manual_langs
    raw <- setNames(lapply(langs, function(lang) {
      v <- input[[manual_id(lang)]]
      if (is.null(v)) manual_store[[lang]] else v
    }), langs)
    build_language_mix(raw)
  }

  # Push a parameter list (and optionally line counts) into the inputs
  apply_params <- function(p, mix = NULL) {
    p <- utils::modifyList(PARAM_DEFAULTS, Filter(Negate(is.null), p))
    updateSelectInput(session, "analyze_complexity", selected = p$complexity)
    updateSliderInput(session, "analyze_team_exp", value = p$team_exp)
    for (k in c("reuse", "tools", "rely", "cplx", "ruse", "pcon", "apex")) {
      updateSelectInput(session, paste0("analyze_", k),
                        selected = as.character(nearest_level(p[[k]], k)))
    }
    updateNumericInput(session, "analyze_wage", value = p$wage)
    updateSliderInput(session, "analyze_max_team", value = p$max_team)
    updateSliderInput(session, "analyze_max_schedule", value = p$max_schedule)
    updateSliderInput(session, "analyze_maint_rate", value = round(p$maintenance_rate * 100))
    updateSliderInput(session, "analyze_maint_years", value = p$maintenance_years)
    updateRadioButtons(session, "analyze_framework", selected = p$framework)
    if (!is.null(mix)) {
      mix <- clean_language_mix(mix)
      # Languages the picker does not list (from a scan or an old link) are kept
      # under their own name; the picker gains them as choices.
      langs <- names(mix)
      for (lang in langs) {
        manual_store[[lang]] <- mix[[lang]]
        updateNumericInput(session, manual_id(lang), value = mix[[lang]])
      }
      updateSelectizeInput(session, "manual_langs", choices = union(MANUAL_LANGUAGES, langs),
                           selected = langs)
      updateRadioButtons(session, "input_method", selected = "manual")
    }
  }

  # ── Reset with undo ───────────────────────────────────────────────────────
  previous_params <- reactiveVal(NULL)
  observeEvent(input$reset_params, {
    previous_params(analyze_params())
    apply_params(PARAM_DEFAULTS)
    showNotification(
      tagList("Parameters reset to defaults. ",
              actionLink("undo_reset", "Undo", class = "btn-link")),
      id = "reset_toast", type = "message", duration = 15
    )
  })
  observeEvent(input$undo_reset, {
    if (!is.null(previous_params())) apply_params(previous_params())
    removeNotification("reset_toast")
    showNotification("Previous parameters restored.", type = "message", duration = 3)
  })

  # ── Inline validation ─────────────────────────────────────────────────────
  field_error <- function(msg) {
    tags$div(class = "field-error", role = "alert",
             icon("circle-exclamation", `aria-hidden` = "true"), msg)
  }
  errors <- reactiveValues(manual = NULL, zip = NULL, local = NULL)
  output$manual_error <- renderUI(if (!is.null(errors$manual)) field_error(errors$manual))
  output$zip_error    <- renderUI(if (!is.null(errors$zip))    field_error(errors$zip))
  output$local_error  <- renderUI(if (!is.null(errors$local))  field_error(errors$local))
  observeEvent(input$manual_langs, errors$manual <- NULL, ignoreInit = TRUE)
  observeEvent(input$zip_file,    errors$zip   <- NULL, ignoreInit = TRUE)
  observeEvent(input$local_path,  errors$local <- NULL, ignoreInit = TRUE)

  # ── Browse folder (local only) ────────────────────────────────────────────
  if (!is_deployed) {
    observeEvent(input$browse_folder, {
      path <- tryCatch({
        if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
          selected <- rstudioapi::selectDirectory(caption = "Select repository folder")
          if (!is.null(selected) && nzchar(selected)) return(selected)
        }
        if (Sys.info()[["sysname"]] == "Darwin") {
          cmd <- "osascript -e 'POSIX path of (choose folder with prompt \"Select repository folder\")'"
          res <- suppressWarnings(system(cmd, intern = TRUE, ignore.stderr = TRUE))
          if (length(res) > 0 && nzchar(res[1])) {
            selected <- sub("/$", "", trimws(res[1]))
            if (nzchar(selected)) return(selected)
          }
        }
        if (requireNamespace("tcltk", quietly = TRUE)) {
          selected <- tcltk::tk_choose.dir(caption = "Select repository folder")
          if (!is.null(selected) && nzchar(selected)) return(selected)
        }
        stop("No folder selection method succeeded")
      }, error = function(e) {
        errors$local <- "The folder picker is not available here. Type the path instead."
        NULL
      })
      if (!is.null(path) && nzchar(path)) updateTextInput(session, "local_path", value = path)
    })
  }

  # ── Run: counts the code (parameters are live, see analyze_params) ───────
  scan_with_progress <- function(path, message, from = 0) {
    started <- Sys.time()
    withProgress(message = message, value = from, {
      capture.output({
        analysis <- analyze_repo_code(
          path                = path,
          avg_wage            = analyze_params()$wage,
          complexity          = analyze_params()$complexity,
          team_experience     = analyze_params()$team_exp,
          reuse_factor        = analyze_params()$reuse,
          tool_support        = analyze_params()$tools,
          max_team_size       = analyze_params()$max_team,
          max_schedule_months = analyze_params()$max_schedule,
          framework           = analyze_params()$framework,
          progress_callback   = function(current, total) {
            elapsed <- as.integer(difftime(Sys.time(), started, units = "secs"))
            setProgress(
              value  = from + (1 - from) * (current / total),
              detail = sprintf("%d:%02d elapsed · file %d of %d",
                               elapsed %/% 60, elapsed %% 60, current, total)
            )
          }
        )
      })
      analysis
    })
  }

  set_error <- function(msg, why) {
    results$analyze <- list(error = list(msg = msg, why = why))
  }

  run_now <- function() {
    method <- input$input_method
    errors$manual <- NULL; errors$zip <- NULL; errors$local <- NULL

    if (method == "local") {
      path <- input$local_path
      if (is.null(path) || !nzchar(path) || !dir.exists(path)) {
        errors$local <- "That folder does not exist. Check the path or use Browse."
        return(invisible(NULL))
      }
      analysis <- tryCatch(scan_with_progress(path, "Counting lines of code"),
                           error = function(e) e)
      if (inherits(analysis, "error")) {
        set_error("Could not scan the folder",
                  paste0("The scanner stopped with: ", conditionMessage(analysis),
                         ". Check that the folder is readable and try again."))
        return(invisible(NULL))
      }
      if (is.null(analysis) || nrow(analysis) == 0 || sum(analysis$Code) == 0) {
        set_error("No code found in that folder",
                  "Only documentation or configuration files were found, and those are never billed. Point at a folder with source code.")
        return(invisible(NULL))
      }
      results$analyze <- list(lang_summary = analysis,
                              source_label = basename(normalizePath(path)))

    } else if (method == "zip") {
      f <- input$zip_file
      if (is.null(f)) {
        errors$zip <- "Choose a .zip file first."
        return(invisible(NULL))
      }
      if (file.info(f$datapath)$size > 50 * 1024 * 1024) {
        errors$zip <- "That file is over 50 MB. Zip only the source folders, without data or build output."
        return(invisible(NULL))
      }
      temp_dir <- tempfile(pattern = "zip_analysis_")
      dir.create(temp_dir)
      on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

      ok <- tryCatch({ unzip(f$datapath, exdir = temp_dir); TRUE },
                     error = function(e) FALSE, warning = function(w) FALSE)
      extracted <- list.files(temp_dir, recursive = TRUE, full.names = TRUE)
      if (!ok || length(extracted) == 0) {
        set_error("Could not read the ZIP archive",
                  "The file could not be extracted. Re-zip the project folder and upload it again.")
        return(invisible(NULL))
      }
      relative <- gsub(paste0("^", normalizePath(temp_dir)), "", normalizePath(extracted))
      if (any(grepl("\\.\\.", relative))) {
        set_error("The ZIP archive was rejected",
                  "It contains paths that point outside the archive (path traversal). Re-zip the folder with a standard tool.")
        return(invisible(NULL))
      }
      folders <- list.dirs(temp_dir, recursive = FALSE)
      folders <- folders[!grepl("^__MACOSX$|^\\.", basename(folders))]
      repo_path <- if (length(folders) > 0) folders[1] else temp_dir

      analysis <- tryCatch(scan_with_progress(repo_path, "Counting lines of code", from = 0.15),
                           error = function(e) e)
      if (inherits(analysis, "error")) {
        set_error("Could not scan the archive",
                  paste0("The scanner stopped with: ", conditionMessage(analysis), "."))
        return(invisible(NULL))
      }
      if (is.null(analysis) || nrow(analysis) == 0 || sum(analysis$Code) == 0) {
        set_error("No code found in the archive",
                  "Only documentation or configuration files were found, and those are never billed. Zip a folder that contains source code.")
        return(invisible(NULL))
      }
      results$analyze <- list(lang_summary = analysis,
                              source_label = tools::file_path_sans_ext(basename(f$name)))

    } else {
      language_mix <- current_manual_mix()
      if (length(language_mix) == 0) {
        errors$manual <- "Add a language and enter a line count above zero."
        return(invisible(NULL))
      }
      results$analyze <- list(language_mix = language_mix, source_label = "Manual entry")
    }
    invisible(TRUE)
  }

  observeEvent(input$run_analysis, run_now())

  # ── Results module ────────────────────────────────────────────────────────
  handles <- analysisResultsServer(
    "analyze_results",
    analysis_data = reactive(results$analyze),
    params        = analyze_params,
    mode          = mode,
    pdf_available = pdf_report_available()
  )

  # "Run this example" from the first-run screen or an error state
  observeEvent(handles$run_example(), {
    apply_params(PARAM_DEFAULTS, EXAMPLE_MIX)
    results$analyze <- list(language_mix = EXAMPLE_MIX, source_label = "Worked example")
  })

  # ── Scenarios ─────────────────────────────────────────────────────────────
  comp <- comparisonServer("compare", mode = mode)
  observeEvent(handles$save_scenario(), {
    snap <- handles$snapshot()
    req(snap)
    n <- comp$add(snap)
    if (!is.null(n)) {
      nav_select("nav", selected = "scenarios")
      showNotification(sprintf("Saved as Scenario %d.", n), type = "message", duration = 4)
    }
  })
  observeEvent(comp$go_estimate(), nav_select("nav", selected = "estimate"))

  # ── Plan advisor: apply a plan to the caps (with undo) or save it ────────
  previous_caps <- reactiveVal(NULL)
  observeEvent(handles$apply_plan(), {
    pl <- handles$apply_plan(); req(pl)
    previous_caps(list(max_team = analyze_params()$max_team, max_schedule = analyze_params()$max_schedule))
    updateSliderInput(session, "analyze_max_team", value = pl$max_team)
    updateSliderInput(session, "analyze_max_schedule", value = pl$max_schedule)
    showNotification(
      tagList(sprintf("Applied: team cap %d, schedule cap %s. ", pl$max_team, fmt_months(pl$max_schedule)),
              actionLink("undo_apply", "Undo", class = "btn-link")),
      id = "apply_toast", type = "message", duration = 15
    )
  })
  observeEvent(input$undo_apply, {
    pc <- previous_caps(); req(pc)
    updateSliderInput(session, "analyze_max_team", value = pc$max_team)
    updateSliderInput(session, "analyze_max_schedule", value = pc$max_schedule)
    removeNotification("apply_toast")
    showNotification("Previous caps restored.", type = "message", duration = 3)
  })
  observeEvent(handles$save_plan(), {
    snap <- handles$save_plan(); req(snap)
    n <- comp$add(snap)
    if (!is.null(n)) showNotification(sprintf("Saved as Scenario %d. Open Scenarios to compare.", n),
                                      type = "message", duration = 5)
  })

  # ── URL state: the address bar is always the share link ───────────────────
  observe({
    snap <- handles$snapshot()
    req(snap)
    updateQueryString(paste0("?", build_share_query(snap$params, snap$language_mix, snap$know)),
                      mode = "replace", session = session)
  })

  # Inbound share link: fill the inputs and show the estimate immediately
  observeEvent(session$clientData$url_search, {
    shared <- parse_share_query(parseQueryString(session$clientData$url_search))
    if (is.null(shared)) return()
    mix <- Filter(function(x) x > 0, shared$mix)
    if (length(mix) == 0) return()
    apply_params(shared$params, mix)
    if (!is.null(shared$know$people)) updateNumericInput(session, "analyze_results-know_people", value = shared$know$people)
    if (!is.null(shared$know$months)) updateNumericInput(session, "analyze_results-know_months", value = shared$know$months)
    if (!is.null(shared$know$budget)) updateNumericInput(session, "analyze_results-know_budget", value = shared$know$budget)
    results$analyze <- list(language_mix = mix, source_label = "Shared link")
    nav_select("nav", selected = "estimate")
    showNotification("Estimate opened from a shared link.", type = "message", duration = 5)
  }, once = TRUE)
}

shinyApp(ui = ui, server = server)
