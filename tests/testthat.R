# Run tests for the Shiny Cost Estimator
# Usage: Rscript tests/testthat.R (from project root)
#
# On CI (CI=true) a warning fails the run, so a drifting dependency or a
# deprecated call is caught before it reaches users. Locally, warnings are
# reported but do not fail the suite.

library(testthat)

# Source the estimation functions
source("R/shiny_cost_estimator.R")

strict <- nzchar(Sys.getenv("CI")) || identical(Sys.getenv("TESTTHAT_STRICT"), "true")

test_dir("tests/testthat", stop_on_failure = TRUE, stop_on_warning = strict)
