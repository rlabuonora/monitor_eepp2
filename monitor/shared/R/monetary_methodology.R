default_monetary_methodology <- function() {
  list(
    base_year = 2024L,
    projection_year = 2025L,
    ui_choices = list(
      annual = c(
        "Millones de $ corr." = "valor",
        "Millones de $ ctes. 2024" = "valor_2024",
        "Millones de USD" = "valor_usd",
        "% del PIB" = "valor_pct_pib"
      ),
      projection = c(
        "Millones de $ corr." = "ejecutado",
        "Millones de $ ctes. 2024" = "ejecutado_2024",
        "Millones de USD" = "ejecutado_usd",
        "% del PIB" = "ejecutado_pct_pib"
      )
    ),
    output_columns = list(
      annual = list(
        nominal = "valor",
        constant = "valor_2024",
        usd = "valor_usd",
        pct_pib = "valor_pct_pib"
      ),
      projection = list(
        nominal = "ejecutado",
        constant = "ejecutado_2024",
        usd = "ejecutado_usd",
        pct_pib = "ejecutado_pct_pib"
      )
    ),
    reference_series = list(
      ipc = list(dataset_id = "serie_ipc_anual_24", value_col = "ipc_base_24"),
      pib = list(dataset_id = "serie_pib_anual", value_col = "pib_nominal"),
      exchange_rate = list(
        dataset_id = "dolar_promedio_anual",
        value_col = "dolar_promedio",
        convention = "annual_average"
      )
    ),
    assumptions = list(
      pib_nominal_growth_for_projection = 0.025
    )
  )
}

monetary_unit_choices <- function(scope = c("annual", "projection"), methodology = default_monetary_methodology()) {
  scope <- match.arg(scope)
  methodology$ui_choices[[scope]]
}

monetary_constant_unit_label <- function(methodology = default_monetary_methodology()) {
  names(methodology$ui_choices$annual)[names(methodology$ui_choices$annual) == methodology$output_columns$annual$constant]
}

validate_reference_series_table <- function(df, name, value_col) {
  if (!is.data.frame(df)) {
    stop(sprintf("Reference series '%s' is not a data frame.", name), call. = FALSE)
  }

  required_cols <- c("year", value_col)
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(sprintf("Reference series '%s' is missing columns: %s", name, paste(missing_cols, collapse = ", ")), call. = FALSE)
  }

  if (anyDuplicated(df$year) > 0) {
    stop(sprintf("Reference series '%s' has duplicate years.", name), call. = FALSE)
  }

  if (any(is.na(df$year))) {
    stop(sprintf("Reference series '%s' has missing years.", name), call. = FALSE)
  }

  if (any(is.na(df[[value_col]]))) {
    stop(sprintf("Reference series '%s' has missing values in column '%s'.", name, value_col), call. = FALSE)
  }

  if (any(df[[value_col]] <= 0)) {
    stop(sprintf("Reference series '%s' must be strictly positive in column '%s'.", name, value_col), call. = FALSE)
  }
}

validate_monetary_reference_series <- function(macro_series, methodology = default_monetary_methodology(), required_years = NULL) {
  validate_reference_series_table(macro_series$ipc_anual, "ipc_anual", methodology$reference_series$ipc$value_col)
  validate_reference_series_table(macro_series$pib_nominal_anual, "pib_nominal_anual", methodology$reference_series$pib$value_col)
  validate_reference_series_table(macro_series$dolar_promedio_anual, "dolar_promedio_anual", methodology$reference_series$exchange_rate$value_col)

  base_year <- methodology$base_year
  if (!(base_year %in% macro_series$ipc_anual$year)) {
    stop(sprintf("IPC reference series does not include the base year %s.", base_year), call. = FALSE)
  }

  if (!is.null(required_years) && length(required_years) > 0) {
    required_years <- sort(unique(as.integer(required_years)))
    series_map <- list(
      ipc_anual = macro_series$ipc_anual$year,
      pib_nominal_anual = macro_series$pib_nominal_anual$year,
      dolar_promedio_anual = macro_series$dolar_promedio_anual$year
    )

    for (series_name in names(series_map)) {
      missing_years <- setdiff(required_years, series_map[[series_name]])
      if (length(missing_years) > 0) {
        stop(
          sprintf(
            "Reference series '%s' is missing required years: %s",
            series_name,
            paste(missing_years, collapse = ", ")
          ),
          call. = FALSE
        )
      }
    }
  }

  invisible(macro_series)
}

augment_monetary_measures <- function(df, nominal_col, macro_series,
                                      methodology = default_monetary_methodology(),
                                      year_col = "year",
                                      output_cols = list(
                                        constant = "valor_2024",
                                        pct_pib = "valor_pct_pib",
                                        usd = "valor_usd"
                                      )) {
  if (!is.data.frame(df)) {
    stop("augment_monetary_measures() expects a data frame.", call. = FALSE)
  }

  missing_cols <- setdiff(c(year_col, nominal_col), names(df))
  if (length(missing_cols) > 0) {
    stop(sprintf("augment_monetary_measures() is missing columns: %s", paste(missing_cols, collapse = ", ")), call. = FALSE)
  }

  required_years <- sort(unique(stats::na.omit(as.integer(df[[year_col]]))))
  validate_monetary_reference_series(macro_series, methodology = methodology, required_years = required_years)

  ipc_value_col <- methodology$reference_series$ipc$value_col
  pib_value_col <- methodology$reference_series$pib$value_col
  usd_value_col <- methodology$reference_series$exchange_rate$value_col

  df[["..row_id"]] <- seq_len(nrow(df))

  joined <- merge(
    df,
    macro_series$ipc_anual,
    by.x = year_col,
    by.y = "year",
    all.x = TRUE,
    sort = FALSE
  )
  joined <- merge(
    joined,
    macro_series$pib_nominal_anual,
    by.x = year_col,
    by.y = "year",
    all.x = TRUE,
    sort = FALSE
  )
  joined <- merge(
    joined,
    macro_series$dolar_promedio_anual,
    by.x = year_col,
    by.y = "year",
    all.x = TRUE,
    sort = FALSE
  )
  joined <- joined[order(joined[["..row_id"]]), , drop = FALSE]

  joined[[output_cols$constant]] <- 100 * joined[[nominal_col]] / joined[[ipc_value_col]]
  joined[[output_cols$pct_pib]] <- joined[[nominal_col]] / joined[[pib_value_col]]
  joined[[output_cols$usd]] <- joined[[nominal_col]] / joined[[usd_value_col]]

  joined[, setdiff(names(joined), c("..row_id", ipc_value_col, pib_value_col, usd_value_col)), drop = FALSE]
}
