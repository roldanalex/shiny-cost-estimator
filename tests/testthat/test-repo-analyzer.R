# Tests for analyze_repo_code(): Billable classification and the guarantee
# that docs/config lines do not move the cost estimate.

local({
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  source(file.path(root, "R", "repo_code_analyzer.R"), local = FALSE)
})

make_fixture <- function() {
  dir <- file.path(tempdir(), paste0("fixture_", sample.int(1e6, 1)))
  dir.create(dir)
  writeLines(c("f <- function(x) {", "  x + 1", "}", rep("y <- 1", 200)),
             file.path(dir, "code.R"))
  writeLines(rep("print('hello')", 100), file.path(dir, "script.py"))
  writeLines(rep("Some documentation text.", 500), file.path(dir, "README.md"))
  writeLines(c("{", paste0('  "k', 1:300, '": 1,'), "}"),
             file.path(dir, "config.json"))
  dir
}

test_that("analyzer flags docs/config as non-billable", {
  dir <- make_fixture()
  on.exit(unlink(dir, recursive = TRUE))
  res <- capture.output(summary <- analyze_repo_code(dir))
  expect_true("Billable" %in% names(summary))
  expect_true(summary$Billable[summary$Language == "R"])
  expect_true(summary$Billable[summary$Language == "Python"])
  expect_false(summary$Billable[summary$Language == "Markdown"])
  expect_false(summary$Billable[summary$Language == "JSON"])
})

test_that("docs/config lines do not change the cost estimate", {
  dir_code <- file.path(tempdir(), paste0("code_only_", sample.int(1e6, 1)))
  dir.create(dir_code)
  on.exit(unlink(dir_code, recursive = TRUE), add = TRUE)
  writeLines(rep("y <- 1", 1000), file.path(dir_code, "code.R"))

  dir_both <- file.path(tempdir(), paste0("code_docs_", sample.int(1e6, 1)))
  dir.create(dir_both)
  on.exit(unlink(dir_both, recursive = TRUE), add = TRUE)
  writeLines(rep("y <- 1", 1000), file.path(dir_both, "code.R"))
  writeLines(rep("Docs docs docs.", 5000), file.path(dir_both, "README.md"))

  out_code <- capture.output(analyze_repo_code(dir_code))
  out_both <- capture.output(analyze_repo_code(dir_both))

  cost_line <- function(out) grep("Estimated Cost to Develop", out, value = TRUE)
  expect_equal(cost_line(out_code), cost_line(out_both))
})

test_that("scanner recognises the general-purpose languages and bills them", {
  dir <- file.path(tempdir(), paste0("langs_", sample.int(1e6, 1)))
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  files <- c("main.go" = "Go", "lib.rs" = "Rust", "App.cs" = "C#", "Main.kt" = "Kotlin",
             "View.swift" = "Swift", "index.php" = "PHP", "app.rb" = "Ruby", "model.jl" = "Julia",
             "Job.scala" = "Scala", "ui.ts" = "TypeScript", "Main.java" = "Java", "core.c" = "C")
  for (f in names(files)) writeLines(rep("x = 1", 20), file.path(dir, f))
  res <- capture.output(summary <- analyze_repo_code(dir))
  for (lang in unname(files)) {
    expect_true(lang %in% summary$Language, info = lang)
    expect_true(summary$Billable[summary$Language == lang], info = lang)
    expect_equal(summary$Code[summary$Language == lang], 20, info = lang)
  }
})

test_that("framework passes through the scanner to the estimate", {
  dir <- file.path(tempdir(), paste0("fw_", sample.int(1e6, 1)))
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  writeLines(rep("int x = 1;", 2000), file.path(dir, "core.c"))
  out_m <- capture.output(analyze_repo_code(dir))
  out_s <- capture.output(analyze_repo_code(dir, framework = "systems"))
  cost <- function(out) as.numeric(gsub("[^0-9]", "", grep("Estimated Cost", out, value = TRUE)[1]))
  expect_equal(cost(out_s) / cost(out_m), 1 / 0.85, tolerance = 0.01)
})
