#!/usr/bin/env Rscript
# Quick launcher for Software Cost Estimator
# Usage: Rscript run_app.R [port]

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) > 0) as.integer(args[1]) else 3838

# Print banner
cat("\n")
cat("╔═══════════════════════════════════════════════════════════╗\n")
cat("║                                                           ║\n")
cat("║           SOFTWARE COST ESTIMATOR                        ║\n")
cat("║        COCOMO II-Based Development Cost Analysis         ║\n")
cat("║                                                           ║\n")
cat("╚═══════════════════════════════════════════════════════════╝\n")
cat("\n")

# Check if running from correct directory
if (!file.exists("app.R")) {
  cat("Error: app.R not found!\n")
  cat("   Please run this script from the cost-estimator-app directory:\n")
  cat("   cd cost-estimator-app && Rscript run_app.R\n\n")
  quit(status = 1)
}

# Check dependencies
cat("Checking dependencies...\n")
required_pkgs <- c("shiny", "bslib", "plotly", "DT", "markdown", "jsonlite")
missing <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]

if (length(missing) > 0) {
  cat("Missing required packages:", paste(missing, collapse = ", "), "\n")
  cat("\n")
  cat("Installing missing packages...\n")
  install.packages(missing, repos = "https://cran.rstudio.com/")
}

cat("All dependencies satisfied\n\n")

# Check source files
if (!file.exists("../R/shiny_cost_estimator.R") || !file.exists("../R/repo_code_analyzer.R")) {
  cat("Error: Source files not found in ../R/\n")
  cat("   Expected files:\n")
  cat("   - ../R/shiny_cost_estimator.R\n")
  cat("   - ../R/repo_code_analyzer.R\n\n")
  quit(status = 1)
}

# Launch app
cat("═══════════════════════════════════════════════════════════════\n")
cat("Starting Software Cost Estimator...\n")
cat("═══════════════════════════════════════════════════════════════\n\n")
cat("Server will run on:  http://localhost:", port, "\n", sep = "")
cat("Press Ctrl+C to stop\n\n")
cat("Three analysis modes available:\n")
cat("  Manual entry - quick estimates from line counts\n")
cat("  ZIP upload   - upload a repository archive\n")
cat("  Local folder - scan a directory on this computer\n\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

# Run the app
tryCatch({
  shiny::runApp(
    appDir = ".",
    port = port,
    launch.browser = TRUE,
    host = "0.0.0.0"
  )
}, interrupt = function(e) {
  cat("\n\n")
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("Server stopped. Thank you for using Software Cost Estimator.\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
})
