opp_cols <- list(
  dark_blue = "#162755",
  gold = "#DAAA00",
  blue = "#25418E",
  light_blue = "#1B9E77"
)

entes_minimo_ingreso <- c("ANP", "ANTEL", "OSE", "URSEA", "URSEC", "UTE")
entes_minimo_gasto <- c("AFE", "ANCAP", "ANCO", "ANV", "INC")

options(ggplot2.discrete.fill = c(
  opp_cols$dark_blue,
  opp_cols$light_blue,
  opp_cols$gold,
  opp_cols$blue
))

ensure_app_package <- function(package_name, feature) {
  if (!requireNamespace(package_name, quietly = TRUE)) {
    stop(
      sprintf(
        "The '%s' package is required for %s. Install it in your R user library, then run the app again.",
        package_name,
        feature
      ),
      call. = FALSE
    )
  }
}

spinner_wrap <- function(x) {
  if (requireNamespace("shinycssloaders", quietly = TRUE)) {
    return(shinycssloaders::withSpinner(x, color = opp_cols$dark_blue))
  }

  x
}

safe_bs_icon <- function(name) {
  if (requireNamespace("bsicons", quietly = TRUE)) {
    icon_tag <- tryCatch(
      bsicons::bs_icon(name),
      error = function(...) NULL
    )
    if (!is.null(icon_tag)) {
      return(icon_tag)
    }
  }

  fallback_name <- switch(
    name,
    bank = "building-columns",
    `cash-coin` = "coins",
    `graph-up-arrow` = "chart-line",
    `piggy-bank` = "piggy-bank",
    tools = "screwdriver-wrench",
    "circle"
  )

  shiny::icon(fallback_name)
}

girafe_output_widget <- function(output_id, width = "100%", height = "540px") {
  ensure_app_package("ggiraph", "interactive plot rendering")
  ggiraph::girafeOutput(output_id, width = width, height = height)
}

render_girafe_widget <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) {
    expr <- substitute(expr)
  }

  ensure_app_package("ggiraph", "interactive plot rendering")
  ggiraph::renderGirafe(expr, env = env, quoted = TRUE)
}

make_girafe_widget <- function(plot_object, width_svg = 20, height_svg = 9) {
  ensure_app_package("ggiraph", "interactive plot rendering")
  ggiraph::girafe(
    ggobj = plot_object,
    width_svg = width_svg,
    height_svg = height_svg,
    options = list(ggiraph::opts_sizing(rescale = TRUE))
  )
}

fmt_amount <- function(x, units) {
  switch(
    units,
    valor = scales::dollar(x, scale = 1e-6, prefix = "$ ", big.mark = ".", decimal.mark = ","),
    valor_2024 = scales::dollar(x, scale = 1e-6, prefix = "$ ", big.mark = ".", decimal.mark = ","),
    valor_usd = scales::dollar(x, scale = 1e-6, prefix = "US$ ", big.mark = ".", decimal.mark = ","),
    valor_pct_pib = scales::percent(x, accuracy = 0.01, big.mark = ".", decimal.mark = ","),
    ejecutado = scales::dollar(x, scale = 1e-6, prefix = "$ ", big.mark = ".", decimal.mark = ","),
    ejecutado_2024 = scales::dollar(x, scale = 1e-6, prefix = "$ ", big.mark = ".", decimal.mark = ","),
    ejecutado_usd = scales::dollar(x, scale = 1e-6, prefix = "US$ ", big.mark = ".", decimal.mark = ","),
    ejecutado_pct_pib = scales::percent(x, accuracy = 0.01, big.mark = ".", decimal.mark = ","),
    x
  )
}

escala_y <- function(unidad) {
  switch(
    unidad,
    valor = ggplot2::scale_y_continuous(labels = scales::dollar_format(scale = 1e-6)),
    valor_usd = ggplot2::scale_y_continuous(labels = scales::dollar_format(prefix = "USD ", scale = 1e-6)),
    valor_2024 = ggplot2::scale_y_continuous(labels = scales::dollar_format(scale = 1e-6)),
    valor_pct_pib = ggplot2::scale_y_continuous(labels = scales::percent_format(scale = 100)),
    ejecutado = ggplot2::scale_y_continuous(labels = scales::dollar_format(scale = 1e-6)),
    ejecutado_usd = ggplot2::scale_y_continuous(labels = scales::dollar_format(prefix = "USD ", scale = 1e-6)),
    ejecutado_2024 = ggplot2::scale_y_continuous(labels = scales::dollar_format(scale = 1e-6)),
    ejecutado_pct_pib = ggplot2::scale_y_continuous(labels = scales::percent_format(scale = 100))
  )
}

agregar_deflactores <- function(df) {
  if (!"year" %in% names(df) || !is.numeric(df$year)) {
    stop("Error: data frame must have a numeric column named 'year'.", call. = FALSE)
  }

  if (!"ejecutado" %in% names(df) || !is.numeric(df$ejecutado)) {
    stop("Error: data frame must have a numeric column named 'ejecutado'.", call. = FALSE)
  }

  ipc_anual <- read_required_dataset("serie_ipc_anual_24") |>
    dplyr::add_row(year = 2025, ipc_base_24 = 105.8)

  tasa_crecimiento_pib <- 0.025
  pib_nominal_anual <- read_required_dataset("serie_pib_anual")
  pib_nominal_proyectado_25 <- (1 + tasa_crecimiento_pib) *
    dplyr::pull(utils::tail(pib_nominal_anual, 1), pib_nominal)

  pib_nominal_anual <- pib_nominal_anual |>
    dplyr::add_row(year = 2025, pib_nominal = pib_nominal_proyectado_25)

  dolar_promedio_anual <- read_required_dataset("dolar_promedio_anual")

  df |>
    dplyr::left_join(ipc_anual, by = "year") |>
    dplyr::left_join(pib_nominal_anual, by = "year") |>
    dplyr::left_join(dolar_promedio_anual, by = "year") |>
    dplyr::mutate(
      ejecutado_2024 = 100 * .data$ejecutado / .data$ipc_base_24,
      ejecutado_pct_pib = .data$ejecutado / .data$pib_nominal,
      ejecutado_usd = .data$ejecutado / .data$dolar_promedio
    ) |>
    dplyr::select(-.data$ipc_base_24, -.data$pib_nominal, -.data$dolar_promedio)
}
