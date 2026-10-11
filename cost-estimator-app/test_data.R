# Example Test Data for Software Cost Estimator

# This file provides sample data you can use to test the app
# Copy these values into the Manual Entry tab

# ============================================================================
# Example 1: Small Shiny Dashboard
# ============================================================================
# Description: Simple dashboard with basic visualizations
# R Code:           3,500 lines
# JavaScript:         500 lines  
# CSS:                300 lines
# Total:            4,300 lines
#
# Recommended Settings:
#   Complexity: Low
#   Team Experience: 4
#   Reuse Factor: 0.9 (some reusable components)
#   Tool Support: 0.9 (good IDE and version control)
#
# Expected Results (v2.0.0 model):
#   Cost: ~$79,000
#   Schedule: ~7 months
#   Team: 1-2 people

example_small <- list(
  r = 3500,
  python = 0,
  js = 500,
  sql = 0,
  css = 300,
  other = 0,
  complexity = "low",
  team_exp = 4,
  reuse = 0.9,
  tools = 0.9
)

# ============================================================================
# Example 2: Medium Analytics Platform
# ============================================================================
# Description: Multi-module analytics app with database integration
# R Code:           8,500 lines
# Python:           2,000 lines (data processing)
# JavaScript:       2,500 lines (interactive charts)
# SQL:              1,200 lines (queries)
# CSS:                800 lines
# Total:           15,000 lines
#
# Recommended Settings:
#   Complexity: Medium
#   Team Experience: 4
#   Reuse Factor: 1.0 (typical project)
#   Tool Support: 0.9
#
# Expected Results (v2.0.0 model):
#   Cost: ~$378,000
#   Schedule: ~12 months
#   Team: 3-4 people

example_medium <- list(
  r = 8500,
  python = 2000,
  js = 2500,
  sql = 1200,
  css = 800,
  other = 0,
  complexity = "medium",
  team_exp = 4,
  reuse = 1.0,
  tools = 0.9
)

# ============================================================================
# Example 3: Enterprise AI-Powered Analytics Platform
# ============================================================================
# Description: Complex platform with AI, real-time data, multi-module
# R Code:          25,000 lines (main modules)
# Python:           5,000 lines (ML/AI processing)
# JavaScript:       4,000 lines (advanced UI)
# SQL:              2,500 lines (complex queries)
# CSS:              1,500 lines (custom styling)
# Markdown:         1,000 lines (documentation)
# Total:           39,000 lines
#
# Recommended Settings:
#   Complexity: High
#   Team Experience: 4
#   Reuse Factor: 0.9 (leveraging frameworks)
#   Tool Support: 0.85 (excellent DevOps)
#
# Expected Results (v2.0.0 model):
#   Cost: ~$1,650,000
#   Schedule: ~24 months (schedule cap)
#   Team: ~7 people

example_large <- list(
  r = 25000,
  python = 5000,
  js = 4000,
  sql = 2500,
  css = 1500,
  other = 1000,
  complexity = "high",
  team_exp = 4,
  reuse = 0.9,
  tools = 0.85
)

# ============================================================================
# Example 4: Quick Prototype
# ============================================================================
# Description: Rapid prototype for proof-of-concept
# R Code:           1,200 lines
# JavaScript:         200 lines
# CSS:                100 lines
# Total:            1,500 lines
#
# Recommended Settings:
#   Complexity: Low
#   Team Experience: 5 (expert)
#   Reuse Factor: 0.7 (lots of template reuse)
#   Tool Support: 0.8
#
# Expected Results (v2.0.0 model):
#   Cost: ~$18,000
#   Schedule: 4-5 months
#   Team: 1 person (part-time)

example_prototype <- list(
  r = 1200,
  python = 0,
  js = 200,
  sql = 0,
  css = 100,
  other = 0,
  complexity = "low",
  team_exp = 5,
  reuse = 0.7,
  tools = 0.8
)

# ============================================================================
# Example 5: Comparison Scenarios
# ============================================================================
# Use these for the "Compare" tab to see impact of different approaches

# Scenario A: Experienced team with good tooling
scenario_a <- list(
  lines = 10000,
  complexity = "medium",
  team_exp = 5,
  reuse = 0.8
)

# Scenario B: Junior team, greenfield
scenario_b <- list(
  lines = 10000,
  complexity = "medium",
  team_exp = 2,
  reuse = 1.2
)

# Scenario C: Complex project, average team
scenario_c <- list(
  lines = 10000,
  complexity = "high",
  team_exp = 3,
  reuse = 1.1
)

# ============================================================================
# How to Use These Examples
# ============================================================================

cat("\n═══════════════════════════════════════════════════════════════\n")
cat("  Test Data Examples for Software Cost Estimator\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

cat("Available examples:\n\n")

cat("1. Small Dashboard (4,300 lines)\n")
cat("   Cost: ~$79K, ~7 months, 1-2 people\n\n")

cat("2. Medium Platform (15,000 lines)\n")
cat("   Cost: ~$378K, ~12 months, 3-4 people\n\n")

cat("3. Large Enterprise Platform (39,000 lines)\n")
cat("   Cost: ~$1.65M, ~24 months, ~7 people\n\n")

cat("4. Quick Prototype (1,500 lines)\n")
cat("   Cost: ~$18K, 4-5 months, 1 person\n\n")

cat("═══════════════════════════════════════════════════════════════\n")
cat("\nTo use an example:\n")
cat("  1. Open the Shiny app\n")
cat("  2. Go to the 'Analyze' tab and select 'Manual Entry'\n")
cat("  3. Enter the values from any example above\n")
cat("  4. Click 'Run Analysis'\n\n")

cat("For comparison scenarios:\n")
cat("  1. Go to 'Compare' tab\n")
cat("  2. Use scenario_a, scenario_b, scenario_c values\n")
cat("  3. See how parameters affect costs side-by-side\n\n")

cat("═══════════════════════════════════════════════════════════════\n\n")

# Print one example in detail
cat("Quick Start - Try Example 1 (Small Dashboard):\n")
cat("─────────────────────────────────────────────────────────────\n")
cat("R Code:        ", example_small$r, "\n")
cat("Python Code:   ", example_small$python, "\n")
cat("JavaScript:    ", example_small$js, "\n")
cat("SQL:           ", example_small$sql, "\n")
cat("CSS:           ", example_small$css, "\n")
cat("Other:         ", example_small$other, "\n")
cat("\nComplexity:    ", example_small$complexity, "\n")
cat("Team Exp:      ", example_small$team_exp, "\n")
cat("Reuse Factor:  ", example_small$reuse, "\n")
cat("Tool Support:  ", example_small$tools, "\n")
cat("═══════════════════════════════════════════════════════════════\n\n")
