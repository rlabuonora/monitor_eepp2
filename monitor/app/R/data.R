opp_cols <- list(
  dark_blue = "#162755",
  gold = "#DAAA00",
  blue = "#25418E",
  light_blue = "#1B9E77"
)

app_monetary_methodology <- function() {
  default_monetary_methodology()
}

annual_unit_choices <- function() {
  monetary_unit_choices("annual", methodology = app_monetary_methodology())
}

annual_unit_choice_list <- function() {
  choices <- annual_unit_choices()
  stats::setNames(as.list(unname(choices)), names(choices))
}

load_app_macro_series <- function(methodology = app_monetary_methodology()) {
  macro_series <- list(
    ipc_anual = read_required_dataset(methodology$reference_series$ipc$dataset_id),
    pib_nominal_anual = read_required_dataset(methodology$reference_series$pib$dataset_id),
    dolar_promedio_anual = read_required_dataset(methodology$reference_series$exchange_rate$dataset_id)
  )

  validate_monetary_reference_series(macro_series, methodology = methodology)
  macro_series
}

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
    valor_usd = ggplot2::scale_y_continuous(labels = scales::dollar_format(prefix = "US$ ", scale = 1e-6)),
    valor_2024 = ggplot2::scale_y_continuous(labels = scales::dollar_format(scale = 1e-6)),
    valor_pct_pib = ggplot2::scale_y_continuous(labels = scales::percent_format(scale = 100)),
    ejecutado = ggplot2::scale_y_continuous(labels = scales::dollar_format(scale = 1e-6)),
    ejecutado_usd = ggplot2::scale_y_continuous(labels = scales::dollar_format(prefix = "US$ ", scale = 1e-6)),
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

  methodology <- app_monetary_methodology()
  augment_monetary_measures(
    df,
    nominal_col = "ejecutado",
    macro_series = load_app_macro_series(methodology = methodology),
    methodology = methodology,
    output_cols = methodology$output_columns$projection[c("constant", "pct_pib", "usd")]
  )
}
