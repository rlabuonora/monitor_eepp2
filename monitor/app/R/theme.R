ggplot2::theme_set(
  ggplot2::theme_minimal(base_family = "system-ui", base_size = 18) +
    ggplot2::theme(plot.title = ggplot2::element_text(hjust = 0.5))
)

opp_theme <- bslib::bs_theme(
  version = 5,
  primary = opp_cols$blue,
  secondary = opp_cols$dark_blue,
  info = opp_cols$light_blue,
  warning = opp_cols$gold,
  base_font = "system-ui",
  heading_font = "system-ui",
  code_font = bslib::font_google("JetBrains Mono", local = TRUE)
)
