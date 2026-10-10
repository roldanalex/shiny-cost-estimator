# Static ggplot2 versions of the app's key charts for the PDF report.
# Colours arrive in the payload (d$colors) straight from modules/theme.R and
# the cost steps come from cost_steps(), so the report always matches the app.
# Number formatting comes from app_helpers.R (copied next to this file at
# render time), so the PDF rounds exactly like the screen.

library(ggplot2)

# Register the bundled fonts with the graphics device (ragg honours
# systemfonts registrations). Returns the family name to use.
register_report_fonts <- function(dir = "fonts") {
  fam <- "sans"
  ok <- tryCatch({
    if (requireNamespace("systemfonts", quietly = TRUE) &&
        file.exists(file.path(dir, "SourceSans3-Regular.ttf"))) {
      if (!"Source Sans 3" %in% systemfonts::registry_fonts()$family) {
        systemfonts::register_font(
          "Source Sans 3",
          plain  = file.path(dir, "SourceSans3-Regular.ttf"),
          bold   = file.path(dir, "SourceSans3-Semibold.ttf"),
          italic = file.path(dir, "SourceSans3-It.ttf")
        )
      }
      fam <- "Source Sans 3"
    }
    TRUE
  }, error = function(e) FALSE)
  fam
}

report_theme <- function(colors, family = "sans") {
  theme_minimal(base_size = 11, base_family = family) +
    theme(
      text = element_text(color = colors$ink),
      axis.text = element_text(color = colors$ink_muted, size = 8.5),
      axis.title = element_text(color = colors$ink_muted, size = 9),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = colors$border, linewidth = 0.3),
      plot.title = element_text(size = 11, face = "bold", color = colors$ink),
      plot.subtitle = element_text(size = 8.5, color = colors$ink_muted),
      plot.title.position = "plot",
      plot.background = element_rect(fill = "transparent", colour = NA),
      legend.position = "bottom",
      legend.text = element_text(size = 8.5)
    )
}

dollar_axis <- function() {
  scale_y_continuous(labels = scales::label_dollar(scale_cut = scales::cut_short_scale()),
                     expand = expansion(mult = c(0, 0.12)))
}

signed_short <- function(x) {
  ifelse(x >= 0, paste0("+", fmt_usd_short(x)), paste0("−", fmt_usd_short(abs(x))))
}

# Waterfall from the shared cost steps; labelled; totals exactly to the hero
gg_waterfall <- function(steps, colors, family = "sans") {
  df <- steps
  df$start <- ifelse(df$kind %in% c("base", "total"), 0, df$running - df$delta)
  df$end   <- ifelse(df$kind %in% c("base", "total"), df$delta, df$running)
  df$type  <- ifelse(df$kind %in% c("base", "total"), "total",
                     ifelse(df$delta >= 0, "increase", "decrease"))
  df$label <- ifelse(df$type == "total", fmt_usd_short(df$delta), signed_short(df$delta))
  df$name  <- factor(df$name, levels = df$name)

  ggplot(df, aes(x = name)) +
    geom_rect(aes(xmin = as.numeric(name) - 0.38, xmax = as.numeric(name) + 0.38,
                  ymin = pmin(start, end), ymax = pmax(start, end), fill = type)) +
    geom_text(aes(y = pmax(start, end), label = label), vjust = -0.5, size = 2.7,
              color = colors$ink, family = family) +
    scale_fill_manual(values = c(total = colors$primary, increase = colors$increase,
                                 decrease = colors$decrease), guide = "none") +
    dollar_axis() +
    labs(title = "How the cost is built",
         subtitle = "Base effort at your developer-year cost, then each factor; the bars sum to the estimate",
         x = NULL, y = NULL) +
    report_theme(colors, family) +
    theme(axis.text.x = element_text(angle = if (nrow(df) > 7) 30 else 0,
                                     hjust = if (nrow(df) > 7) 1 else 0.5))
}

# Ranked drivers: the same deltas as the waterfall, largest first
gg_driver_tornado <- function(steps, colors, family = "sans") {
  df <- steps[steps$kind %in% c("multiplier", "premium") & abs(steps$delta) >= 0.5, ]
  if (nrow(df) == 0) return(NULL)
  df <- df[order(abs(df$delta)), ]
  df$name  <- factor(df$name, levels = df$name)
  df$label <- signed_short(df$delta)
  df$hjust <- ifelse(df$delta >= 0, -0.15, 1.15)

  ggplot(df, aes(x = delta, y = name, fill = delta >= 0)) +
    geom_col(width = 0.7) +
    geom_text(aes(label = label, hjust = hjust), size = 2.7, color = colors$ink, family = family) +
    geom_vline(xintercept = 0, color = colors$ink_muted, linewidth = 0.3) +
    scale_fill_manual(values = c(`TRUE` = colors$increase, `FALSE` = colors$decrease), guide = "none") +
    scale_x_continuous(labels = scales::label_dollar(scale_cut = scales::cut_short_scale()),
                       expand = expansion(mult = 0.25)) +
    labs(title = "Which choices matter most",
         subtitle = "Dollars each driver adds (right) or saves (left)",
         x = NULL, y = NULL) +
    report_theme(colors, family)
}

# Cost at every schedule cap, the chosen cap marked, compressed region shaded
gg_schedule_curve <- function(curve, e, colors, family = "sans") {
  cap <- e$params$max_schedule_months
  natural <- e$natural_schedule_months
  curve <- curve[!is.na(curve$cost), ]
  if (is.null(curve$feasible)) curve$feasible <- TRUE
  bad <- curve[!curve$feasible, ]

  g <- ggplot(curve, aes(x = schedule, y = cost))
  if (natural > min(curve$schedule)) {
    g <- g + annotate("rect", xmin = min(curve$schedule), xmax = min(natural, max(curve$schedule)),
                      ymin = -Inf, ymax = Inf, fill = colors$primary_soft, alpha = 0.6)
    right_side <- natural > 0.6 * max(curve$schedule)
    g <- g + annotate("text", x = min(natural, max(curve$schedule)), y = Inf,
                      label = if (right_side) paste0("natural schedule ", fmt_months(natural), " ")
                              else paste0(" natural schedule ", fmt_months(natural)),
                      hjust = if (right_side) 1 else 0, vjust = 1.5, size = 2.7,
                      color = colors$ink_muted, family = family)
  }
  g <- g + geom_line(color = colors$primary, linewidth = 0.9)
  if (nrow(bad) > 0) {
    g <- g + geom_point(data = bad, shape = 21, fill = NA, color = colors$warning, size = 2.2, stroke = 0.8)
  }
  g +
    geom_point(data = data.frame(schedule = cap, cost = e$cost_usd),
               shape = 23, fill = colors$ink, color = "white", size = 3.4, stroke = 0.8) +
    annotate("text", x = cap, y = e$cost_usd, label = paste0("  your cap: ", fmt_months(cap)),
             hjust = 0, vjust = -0.9, size = 2.8, color = colors$ink, family = family) +
    scale_x_continuous(breaks = seq(6, 60, by = 6)) +
    dollar_axis() +
    labs(title = "What if the deadline moves",
         subtitle = "Cost at each schedule cap; shaded caps carry a compression premium, hollow points exceed your team cap",
         x = "Schedule cap (months)", y = NULL) +
    report_theme(colors, family)
}

# Cumulative cost over time: nominal and today's dollars
gg_tco <- function(e, colors, family = "sans") {
  m <- e$maintenance
  if (is.null(m)) return(NULL)
  years   <- 0:m$maintenance_years
  nominal <- c(0, cumsum(m$yearly_costs)) + e$cost_usd
  pv      <- c(0, cumsum(m$yearly_costs / (1 + m$discount_rate)^seq_along(m$yearly_costs))) + e$cost_usd
  df <- rbind(data.frame(year = years, value = nominal, basis = "Nominal"),
              data.frame(year = years, value = pv, basis = "Today's dollars"))
  df$basis <- factor(df$basis, levels = c("Nominal", "Today's dollars"))

  ggplot(df, aes(x = year, y = value, color = basis, linetype = basis)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 1.8) +
    scale_color_manual(values = c("Nominal" = colors$context, "Today's dollars" = colors$primary), name = NULL) +
    scale_linetype_manual(values = c("Nominal" = "dotted", "Today's dollars" = "solid"), name = NULL) +
    scale_x_continuous(breaks = years) +
    dollar_axis() +
    labs(title = "Cost of ownership over time",
         subtitle = sprintf("Build cost plus %.0f%% maintenance a year, escalating 5%%; discounted at %.0f%% a year",
                            m$maintenance_rate * 100, m$discount_rate * 100),
         x = "Years after launch", y = NULL) +
    report_theme(colors, family)
}

# Staffing curve: fastest practical months per team size, natural schedule dotted
gg_staffing_curve <- function(plan, colors, family = "sans") {
  cv <- plan$curve
  if (is.null(cv) || nrow(cv) == 0) return(NULL)
  kn <- plan$know
  mark_k <- if (!is.null(kn$people)) kn$people else NA
  g <- ggplot(cv, aes(x = k)) +
    annotate("rect", xmin = 5.5, xmax = 8.5, ymin = -Inf, ymax = Inf, fill = colors$warning, alpha = 0.08) +
    annotate("text", x = 8.4, y = Inf, label = "coordination overhead", hjust = 1, vjust = 1.6,
             size = 2.7, color = colors$warning_text, family = family) +
    geom_hline(yintercept = plan$floor_months, linetype = "dashed", color = colors$ink_muted, linewidth = 0.5) +
    annotate("text", x = 0.6, y = plan$floor_months, label = paste0("practical floor ", fmt_months(plan$floor_months)),
             hjust = 0, vjust = -0.6, size = 2.7, color = colors$ink_muted, family = family) +
    geom_line(aes(y = natural_months), color = colors$context, linetype = "dotted", linewidth = 0.8) +
    geom_point(aes(y = natural_months), color = colors$context, size = 1.8) +
    geom_line(aes(y = months), color = colors$primary, linewidth = 0.9, na.rm = TRUE) +
    geom_point(aes(y = months), color = colors$primary, size = 2.2, na.rm = TRUE) +
    geom_text(aes(y = months, label = fmt_usd_short(cost)), vjust = -0.9, size = 2.6,
              color = colors$ink, family = family, na.rm = TRUE)
  if (!is.na(mark_k)) {
    mk <- cv[cv$k == mark_k & !is.na(cv$months), ]
    if (nrow(mk) == 1) g <- g + geom_point(data = mk, aes(y = months), shape = 23, fill = colors$ink,
                                           color = "white", size = 3.4, stroke = 0.8)
  }
  g +
    scale_x_continuous(breaks = 1:8, limits = c(0.5, 8.5)) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.18)), limits = c(0, NA)) +
    labs(title = "Staffing curve",
         subtitle = "Fastest practical months by team size (solid, cost labelled); natural schedule dotted",
         x = "Team size (people)", y = "Months") +
    report_theme(colors, family)
}
