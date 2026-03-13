extract_year_token <- function(x) {
  token <- regmatches(x, regexpr("[0-9]{4}\\*?", x))
  token[token == ""] <- NA_character_
  as.integer(sub("\\*$", "", token))
}

macro_source_filenames <- function() {
  list(
    ipc = "ipc_gral_y_variaciones_base_2022.xlsx",
    exchange_rate = "cotizacion_monedas.xlsx",
    pib = "actividades_c.xlsx"
  )
}

build_macro_series <- function(raw_dir) {
  methodology <- default_monetary_methodology()
  projection_year <- methodology$projection_year
  base_year <- methodology$base_year
  macro_files <- macro_source_filenames()

  pib_path <- file.path(raw_dir, macro_files$pib)
  ipc_path <- file.path(raw_dir, macro_files$ipc)
  exchange_rate_path <- file.path(raw_dir, macro_files$exchange_rate)

  pib_raw <- read_required_excel(pib_path, sheet = "Valores_C", col_types = "text", col_names = FALSE, .name_repair = "minimal")
  pib_headers <- as.character(unlist(pib_raw[6, ]))
  pib_quarter_cols <- grep("^[IVX]+ [0-9]{4}", pib_headers)
  pib_periods <- pib_headers[pib_quarter_cols]
  pib_total_row <- 19L
  pib_year <- extract_year_token(pib_periods)
  pib_value <- suppressWarnings(as.numeric(unlist(pib_raw[pib_total_row, pib_quarter_cols])))
  pib_complete_years <- names(which(table(pib_year[!is.na(pib_year)]) >= 4))
  pib_complete_years <- as.integer(pib_complete_years)
  pib_keep <- !is.na(pib_year) & pib_year >= 2020 & pib_year <= projection_year & pib_year %in% pib_complete_years
  pib_nominal_anual <- stats::aggregate(1e6 * pib_value[pib_keep], by = list(year = pib_year[pib_keep]), FUN = sum, na.rm = TRUE)
  names(pib_nominal_anual)[2] <- "pib_nominal"
  if (!(projection_year %in% pib_nominal_anual$year)) {
    pib_projection <- pib_nominal_anual$pib_nominal[nrow(pib_nominal_anual)] *
      (1 + methodology$assumptions$pib_nominal_growth_for_projection)
    pib_nominal_anual <- rbind(
      pib_nominal_anual,
      data.frame(year = projection_year, pib_nominal = pib_projection)
    )
  }

  ipc_raw <- read_required_excel(ipc_path, sheet = "IPC_Cua 2.0", col_types = "text", col_names = FALSE, .name_repair = "minimal")
  ipc_period_serial <- suppressWarnings(as.numeric(ipc_raw[[1]]))
  ipc_date <- as.Date(ipc_period_serial, origin = "1899-12-30")
  ipc_year <- as.integer(format(ipc_date, "%Y"))
  ipc_month <- as.integer(format(ipc_date, "%m"))
  ipc_value <- suppressWarnings(as.numeric(ipc_raw[[2]]))
  ipc_complete_years <- names(which(tapply(ipc_month, ipc_year, function(x) length(unique(stats::na.omit(x)))) >= 12))
  ipc_complete_years <- as.integer(ipc_complete_years)
  ipc_keep <- !is.na(ipc_year) & ipc_year >= 2020 & ipc_year <= projection_year & ipc_year %in% ipc_complete_years
  ipc_anual <- stats::aggregate(ipc_value[ipc_keep], by = list(year = ipc_year[ipc_keep]), FUN = mean, na.rm = TRUE)
  names(ipc_anual)[2] <- "ipc_promedio_anual"
  ipc_base_year_value <- ipc_anual$ipc_promedio_anual[ipc_anual$year == base_year]
  ipc_anual$ipc_base_24 <- 100 * ipc_anual$ipc_promedio_anual / ipc_base_year_value
  ipc_anual <- ipc_anual[c("year", "ipc_base_24")]

  dolar_raw <- read_required_excel(exchange_rate_path, sheet = "Fuente BROU", col_types = "text", col_names = FALSE, skip = 1, .name_repair = "minimal")
  dolar_date <- parse_legacy_date(dolar_raw[[1]])
  dolar_value <- suppressWarnings(as.numeric(dolar_raw[[3]]))
  dolar_year <- as.integer(format(dolar_date, "%Y"))
  dolar_keep <- !is.na(dolar_year) & dolar_year >= 2020 & dolar_year <= projection_year
  dolar_promedio_anual <- stats::aggregate(
    dolar_value[dolar_keep],
    by = list(year = dolar_year[dolar_keep]),
    FUN = mean,
    na.rm = TRUE
  )
  names(dolar_promedio_anual)[2] <- "dolar_promedio"

  macro_series <- list(
    ipc_anual = ipc_anual,
    pib_nominal_anual = pib_nominal_anual,
    dolar_promedio_anual = dolar_promedio_anual
  )

  validate_monetary_reference_series(macro_series, methodology = methodology)
  macro_series
}

build_proyecciones <- function(proyeccion_path, raw_dir) {
  raw <- read_required_excel(proyeccion_path, range = "A1:J31")
  keep <- !is.na(raw$label) & !is.na(raw$header) & !is.na(raw$SubHeader)
  raw <- as.data.frame(raw[keep, , drop = FALSE], stringsAsFactors = FALSE)

  id_cols <- c("header", "SubHeader", "Item", "label")
  value_cols <- setdiff(names(raw), c(id_cols, "rubro"))

  long_parts <- lapply(value_cols, function(col_name) {
    data.frame(
      header = raw$header,
      SubHeader = as.numeric(raw$SubHeader),
      Item = as.numeric(raw$Item),
      label = raw$label,
      ente = col_name,
      ejecutado = as.numeric(raw[[col_name]]) * 1e3,
      stringsAsFactors = FALSE
    )
  })

  proyecciones <- do.call(rbind, long_parts)
  proyecciones$year <- 2025

  header_map <- c(
    A = "Ingresos",
    B = "Gastos",
    D = "Impuestos y Transferencias",
    E = "Resultado",
    F = "Inversiones",
    G = "Transferencias de Capital"
  )
  header_levels <- c(
    "Ingresos",
    "Gastos",
    "Impuestos y Transferencias",
    "Resultado",
    "Transferencias de Capital",
    "Inversiones"
  )

  proyecciones$header <- unname(header_map[proyecciones$header])
  proyecciones$header <- factor(proyecciones$header, levels = header_levels)

  methodology <- default_monetary_methodology()
  macro <- build_macro_series(raw_dir)
  proyecciones <- augment_monetary_measures(
    proyecciones,
    nominal_col = "ejecutado",
    macro_series = macro,
    methodology = methodology,
    output_cols = methodology$output_columns$projection[c("constant", "pct_pib", "usd")]
  )

  proyecciones$tipo <- "Proyecci\u00f3n"
  proyecciones$ente <- factor(proyecciones$ente, levels = value_cols)

  proyecciones[c(
    "header",
    "label",
    "ente",
    "ejecutado",
    "year",
    "ejecutado_2024",
    "ejecutado_pct_pib",
    "ejecutado_usd",
    "tipo"
  )]
}
