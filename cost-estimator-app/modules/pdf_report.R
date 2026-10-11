# Branded PDF report rendering (Quarto + Typst - no LaTeX or Chrome needed,
# works on shinyapps.io). Shared by the hero toolbar and the summary strip.

pdf_report_available <- function() {
  requireNamespace("quarto", quietly = TRUE) &&
    !is.null(quarto::quarto_path()) &&
    requireNamespace("ggplot2", quietly = TRUE) &&
    dir.exists("report")
}

#' Assemble everything the .qmd needs into one payload. `steps` is the shared
#' cost decomposition (cost_steps()) so the PDF charts match the screen.
build_report_payload <- function(est, billable, curve, project_name,
                                 steps = cost_steps(est), plan = NULL) {
  plan_slim <- if (!is.null(plan)) list(
    narrative = plan$narrative, curve = plan$curve, floor_months = plan$floor_months,
    nominal_months = plan$nominal_months, know = plan$know,
    plans = lapply(plan$recommendations$plans, function(x) x[setdiff(names(x), "est")])
  ) else NULL
  list(
    est          = est,
    billable     = billable[c("total_code", "billable_code", "has_docs")],
    curve        = curve,
    steps        = steps,
    plan         = plan_slim,
    status       = estimate_status(est),
    colors       = app_colors,
    app_version  = if (exists("APP_VERSION")) APP_VERSION else "2.2.0",
    credit       = app_credit(),
    source_url   = APP_SOURCE_URL,
    project_name = project_name,
    generated_on = Sys.Date()
  )
}

#' Render the report to output_file. Renders in a tempdir copy because the
#' deployed app directory is not reliably writable on shinyapps.io. The pure
#' display helpers travel with the report so it formats numbers like the app.
render_estimate_pdf <- function(payload, output_file) {
  work_root <- file.path(tempdir(), paste0("report_", as.integer(Sys.time()),
                                           "_", sample.int(1e6, 1)))
  dir.create(work_root, recursive = TRUE)
  on.exit(unlink(work_root, recursive = TRUE), add = TRUE)

  file.copy("report", work_root, recursive = TRUE)
  work_dir <- file.path(work_root, "report")
  file.copy("modules/app_helpers.R", file.path(work_dir, "app_helpers.R"), overwrite = TRUE)
  saveRDS(payload, file.path(work_dir, "data.rds"))

  quarto::quarto_render(
    input          = file.path(work_dir, "estimate_report.qmd"),
    execute_params = list(data_path = "data.rds"),
    quiet          = TRUE
  )

  pdf_path <- file.path(work_dir, "estimate_report.pdf")
  if (!file.exists(pdf_path)) stop("PDF rendering failed - no output produced.")
  file.copy(pdf_path, output_file, overwrite = TRUE)
  invisible(output_file)
}

#' downloadHandler wrapper: elapsed time and stage, never a countdown
pdf_download_handler <- function(get_payload) {
  downloadHandler(
    filename = function() {
      sprintf("cost-estimate-%s.pdf", format(Sys.Date(), "%Y%m%d"))
    },
    content = function(file) {
      started <- Sys.time()
      stage <- function(detail) {
        el <- as.integer(difftime(Sys.time(), started, units = "secs"))
        sprintf("%d:%02d elapsed · %s", el %/% 60, el %% 60, detail)
      }
      withProgress(message = "Preparing the PDF report", value = 0.2, detail = stage("collecting the estimate"), {
        payload <- get_payload()
        setProgress(0.45, detail = stage("drawing charts and pages"))
        render_estimate_pdf(payload, file)
        setProgress(1, detail = stage("done"))
      })
    }
  )
}
