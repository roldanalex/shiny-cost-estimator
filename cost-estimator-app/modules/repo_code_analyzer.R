# Repository Code Analyzer (scc-style report in R)
# Usage: source this file and call analyze_repo_code(path = ".", avg_wage = 105000)

#' Analyze code in a repository and generate an scc-style report
#' @param path Path to repository root (default: current directory)
#' @param avg_wage Average annual wage for cost estimation (default: 105000)
#' @param complexity Project complexity: "low", "medium", or "high" (default: "medium")
#' @param team_experience Team experience level 1-5 (default: 4)
#' @param reuse_factor Code reuse factor 0.7-1.3 (default: 1.0)
#' @param tool_support Tool support quality 0.8-1.2 (default: 1.0)
#' @param max_team_size Maximum team size constraint (default: 5)
#' @param max_schedule_months Maximum schedule constraint in months (default: 24)
#' @param progress_callback Optional function(current, total) called per file for progress reporting
#' @return Data frame with file statistics by language
analyze_repo_code <- function(
  path = ".",
  avg_wage = 105000,
  complexity = "medium",
  team_experience = 4,
  reuse_factor = 1.0,
  tool_support = 1.0,
  max_team_size = 5,
  max_schedule_months = 24,
  progress_callback = NULL,
  framework = "modern"
) {
  # Language mappings by file extension
  lang_map <- list(
    ".R" = "R",
    ".r" = "R",
    ".js" = "JavaScript",
    ".jsx" = "JavaScript",
    ".ts" = "TypeScript",
    ".tsx" = "TypeScript",
    ".css" = "CSS",
    ".scss" = "Sass",
    ".sass" = "Sass",
    ".html" = "HTML",
    ".htm" = "HTML",
    ".md" = "Markdown",
    ".Rmd" = "Markdown",
    ".qmd" = "Markdown",
    ".yml" = "YAML",
    ".yaml" = "YAML",
    ".json" = "JSON",
    ".xml" = "XML",
    ".svg" = "SVG",
    ".py" = "Python",
    ".tex" = "TeX",
    ".sh" = "Shell",
    ".txt" = "Plain Text",
    ".LICENSE" = "License",
    ".c" = "C",
    ".cpp" = "C++",
    ".h" = "C Header",
    ".java" = "Java",
    ".sql" = "SQL",
    ".go" = "Go",
    ".rs" = "Rust",
    ".cs" = "C#",
    ".kt" = "Kotlin",
    ".kts" = "Kotlin",
    ".swift" = "Swift",
    ".php" = "PHP",
    ".rb" = "Ruby",
    ".jl" = "Julia",
    ".scala" = "Scala",
    ".sc" = "Scala"
  )

  # Comment patterns by language
  comment_patterns <- list(
    "R" = c("^\\s*#"),
    "JavaScript" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "TypeScript" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "CSS" = c("^\\s*/\\*", "^\\s*\\*"),
    "Sass" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "HTML" = c("^\\s*<!--"),
    "Python" = c("^\\s*#"),
    "Shell" = c("^\\s*#"),
    "SQL" = c("^\\s*--", "^\\s*/\\*", "^\\s*\\*"),
    "C" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "C++" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "Java" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "Go" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "Rust" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "C#" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "Kotlin" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "Swift" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*"),
    "PHP" = c("^\\s*//", "^\\s*#", "^\\s*/\\*", "^\\s*\\*"),
    "Ruby" = c("^\\s*#"),
    "Julia" = c("^\\s*#"),
    "Scala" = c("^\\s*//", "^\\s*/\\*", "^\\s*\\*")
  )

  # Get all files recursively, excluding common non-code directories
  all_files <- list.files(
    path,
    recursive = TRUE,
    full.names = TRUE,
    include.dirs = FALSE
  )

  # Exclude directories we don't want to count
  exclude_patterns <- c(
    "/\\.git/", "/\\.Rproj\\.user/", "/node_modules/",
    "/\\.venv/", "/venv/", "/__pycache__/", "/\\.DS_Store$",
    "/\\.Rhistory$", "/\\.RData$", "/packrat/", "/renv/"
  )

  for (pattern in exclude_patterns) {
    all_files <- all_files[!grepl(pattern, all_files)]
  }

  # Known binary file extensions to skip
  binary_extensions <- c(
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ico", ".tiff", ".webp",
    ".woff", ".woff2", ".ttf", ".otf", ".eot",
    ".rds", ".rdata", ".rda", ".rdb", ".rdx",
    ".pyc", ".so", ".dylib", ".dll", ".o", ".class", ".jar",
    ".zip", ".tar", ".gz", ".bz2", ".xz", ".7z", ".rar",
    ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx",
    ".mp3", ".mp4", ".wav", ".avi", ".mov", ".ogg",
    ".sqlite", ".db", ".exe", ".bin", ".dat", ".lock"
  )

  # Check if a file is binary by extension or null bytes in first 8KB
  is_binary_file <- function(filepath, known_exts) {
    ext <- tolower(paste0(".", tools::file_ext(filepath)))
    if (ext %in% known_exts) return(TRUE)
    tryCatch({
      raw_bytes <- readBin(filepath, what = "raw", n = 8192)
      if (length(raw_bytes) == 0) return(FALSE)
      any(raw_bytes == as.raw(0x00))
    }, error = function(e) FALSE)
  }

  # Analyze each file
  total_files <- length(all_files)
  results <- vector("list", total_files)

  for (i in seq_along(all_files)) {
    file <- all_files[[i]]

    # Report progress
    if (!is.null(progress_callback)) {
      progress_callback(i, total_files)
    }

    # Skip binary files
    if (is_binary_file(file, binary_extensions)) {
      results[[i]] <- NULL
      next
    }

    # Get file extension
    ext <- tolower(tools::file_ext(file))
    if (ext == "") {
      if (grepl("LICENSE|LICENCE", basename(file), ignore.case = TRUE)) {
        ext <- ".LICENSE"
      } else {
        ext <- paste0(".", basename(file))
      }
    } else {
      ext <- paste0(".", ext)
    }

    # Map to language
    language <- lang_map[[ext]]
    if (is.null(language)) {
      language <- "Other"
    }

    # Try to read file
    lines <- tryCatch(
      readLines(file, warn = FALSE, encoding = "UTF-8"),
      error = function(e) character(0)
    )

    if (length(lines) == 0) {
      results[[i]] <- NULL
      next
    }

    # Count lines
    total_lines <- length(lines)
    blank_lines <- sum(grepl("^\\s*$", lines))

    # Count comments - single-pass OR to avoid double-counting
    comment_lines <- 0
    patterns <- comment_patterns[[language]]
    if (!is.null(patterns)) {
      is_comment <- rep(FALSE, length(lines))
      for (pattern in patterns) {
        is_comment <- is_comment | grepl(pattern, lines)
      }
      comment_lines <- sum(is_comment)
    }

    # Code lines
    code_lines <- total_lines - blank_lines - comment_lines

    # Rough complexity estimate
    complexity_count <- 0
    if (language == "R") {
      complexity_count <- sum(grepl("function\\s*\\(|for\\s*\\(|while\\s*\\(|if\\s*\\(", lines))
    } else if (language %in% c("JavaScript", "TypeScript")) {
      complexity_count <- sum(grepl("function\\s+|=>|for\\s*\\(|while\\s*\\(|if\\s*\\(|class\\s+", lines))
    } else if (language == "Python") {
      complexity_count <- sum(grepl("def\\s+|class\\s+|for\\s+|while\\s+|if\\s+", lines))
    }

    # Get file size
    file_size <- file.info(file)$size

    results[[i]] <- data.frame(
      Language = language,
      File = file,
      Lines = total_lines,
      Blanks = blank_lines,
      Comments = comment_lines,
      Code = code_lines,
      Complexity = complexity_count,
      Bytes = file_size,
      stringsAsFactors = FALSE
    )
  }

  # Combine results
  results <- do.call(rbind, results[!sapply(results, is.null)])

  if (is.null(results) || nrow(results) == 0) {
    cat("No files found to analyze.\n")
    return(invisible(NULL))
  }

  # Aggregate by language
  lang_summary <- aggregate(
    cbind(Lines, Blanks, Comments, Code, Complexity, Bytes) ~ Language,
    data = results,
    FUN = sum
  )

  # Count files per language
  file_counts <- aggregate(
    File ~ Language,
    data = results,
    FUN = length
  )
  names(file_counts)[2] <- "Files"

  # Merge
  lang_summary <- merge(file_counts, lang_summary, by = "Language")

  # Sort by code lines descending
  lang_summary <- lang_summary[order(-lang_summary$Code), ]

  # Billable classification: documentation, config, and markup formats are
  # counted for transparency but must not drive the cost estimate.
  doc_langs <- c("Markdown", "JSON", "YAML", "SVG", "XML",
                 "Plain Text", "License", "TeX", "Other")
  lang_summary$Billable <- !(lang_summary$Language %in% doc_langs)

  # Calculate totals
  totals <- data.frame(
    Language = "Total",
    Files = sum(lang_summary$Files),
    Lines = sum(lang_summary$Lines),
    Blanks = sum(lang_summary$Blanks),
    Comments = sum(lang_summary$Comments),
    Code = sum(lang_summary$Code),
    Complexity = sum(lang_summary$Complexity),
    Bytes = sum(lang_summary$Bytes)
  )

  # Print report
  cat("\n-----------------------------------------------------------------------\n")
  cat(sprintf("%-20s %9s %9s %9s %9s %9s %10s\n",
              "Language", "Files", "Lines", "Blanks", "Comments", "Code", "Complexity"))
  cat("-----------------------------------------------------------------------\n")

  for (i in 1:nrow(lang_summary)) {
    cat(sprintf("%-20s %9d %9d %9d %9d %9d %10d\n",
                lang_summary$Language[i],
                lang_summary$Files[i],
                lang_summary$Lines[i],
                lang_summary$Blanks[i],
                lang_summary$Comments[i],
                lang_summary$Code[i],
                lang_summary$Complexity[i]))
  }

  cat("-----------------------------------------------------------------------\n")
  cat(sprintf("%-20s %9d %9d %9d %9d %9d %10d\n",
              totals$Language,
              totals$Files,
              totals$Lines,
              totals$Blanks,
              totals$Comments,
              totals$Code,
              totals$Complexity))
  cat("-----------------------------------------------------------------------\n")

  # Calculate cost using COCOMO II
  # Try to find the estimator in common locations (relative to script)
  script_dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "")
  if (is.null(script_dir)) script_dir <- ""
  estimator_paths <- c(
    file.path(script_dir, "shiny_cost_estimator.R"),
    "R/shiny_cost_estimator.R",
    "shiny_cost_estimator.R"
  )

  estimator_path <- NULL
  for (p in estimator_paths) {
    if (file.exists(p)) {
      estimator_path <- p
      break
    }
  }

  # Billable code only - docs/config never drive the estimate
  billable <- lang_summary[lang_summary$Billable, ]

  if (exists("estimate_shiny_cost") || !is.null(estimator_path)) {
    if (!exists("estimate_shiny_cost")) source(estimator_path, local = TRUE)

    # Build language mix for productivity weighting
    language_mix <- setNames(billable$Code, billable$Language)

    # Use enriched estimate_shiny_cost with constraints built in
    cost_result <- estimate_shiny_cost(
      code_lines = sum(billable$Code),
      complexity = complexity,
      team_experience = team_experience,
      reuse_factor = reuse_factor,
      tool_support = tool_support,
      language_mix = language_mix,
      avg_wage = avg_wage,
      max_team_size = max_team_size,
      max_schedule_months = max_schedule_months,
      framework = framework
    )

    non_billable_lines <- totals$Code - sum(billable$Code)
    if (non_billable_lines > 0) {
      cat(sprintf("Note: %s lines of docs/config are excluded from the estimate.\n",
                  format(non_billable_lines, big.mark = ",")))
    }
    cat(sprintf("Estimated Cost to Develop (realistic) $%s\n",
                format(cost_result$cost_usd, big.mark = ",")))
    cat(sprintf("Estimated Schedule Effort (realistic) %.1f months (%.1f years)\n",
                cost_result$final_schedule_months, cost_result$final_schedule_months / 12))
    cat(sprintf("Estimated People Required (realistic) %.0f people\n", cost_result$final_people))

    cat("\nRealistic Project Breakdown:\n")
    cat(sprintf("  Total effort required: %.0f person-months\n", cost_result$effort_person_months))
    cat(sprintf("  Team size: %.0f people\n", cost_result$final_people))
    cat(sprintf("  Timeline: %.1f months\n", cost_result$final_schedule_months))

    if (cost_result$compression_penalty > 1.0) {
      cat(sprintf("  Cost premium: +%.0f%% for aggressive timeline\n",
                  (cost_result$compression_penalty - 1.0) * 100))
    }
    if (cost_result$coordination_premium > 1.0) {
      cat(sprintf("  Coordination overhead: +%.0f%% for team size\n",
                  (cost_result$coordination_premium - 1.0) * 100))
    }
    cat(sprintf("  Average monthly cost: $%s/month\n",
                format(cost_result$average_monthly_cost, big.mark = ",")))
    cat(sprintf("  Estimate range (+/-30%%): $%s - $%s\n",
                format(cost_result$estimate_range$low, big.mark = ","),
                format(cost_result$estimate_range$high, big.mark = ",")))

  } else {
    # Fallback: use basic COCOMO formula (billable code only)
    KLOC <- sum(billable$Code) / 1000
    effort <- 2.94 * (KLOC ^ 1.12)
    schedule <- 3.67 * (effort ^ 0.30)
    people <- effort / schedule
    cost <- effort * (avg_wage / 12)

    cat(sprintf("Estimated Cost to Develop (organic) $%s\n",
                format(round(cost), big.mark = ",")))
    cat(sprintf("Estimated Schedule Effort (organic) %.2f months\n", schedule))
    cat(sprintf("Estimated People Required (organic) %.2f\n", people))
  }

  cat("-----------------------------------------------------------------------\n")
  cat(sprintf("Processed %s bytes, %.3f megabytes (SI)\n",
              format(totals$Bytes, big.mark = ","),
              totals$Bytes / 1000000))
  cat("-----------------------------------------------------------------------\n\n")

  invisible(lang_summary)
}

# Example usage:
# analyze_repo_code(".", avg_wage = 105000, complexity = "medium", team_experience = 4)
# analyze_repo_code("/path/to/other/repo", avg_wage = 120000)
