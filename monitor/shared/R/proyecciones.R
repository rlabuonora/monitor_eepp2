extract_year_token <- function(x) {
  token <- regmatches(x, regexpr("[0-9]{4}\\*?", x))
  token[token == ""] <- NA_character_
  as.integer(sub("\\*$", "", token))
}

build_macro_series <- function(series_path) {
  pib_raw <- read_required_excel(series_path, sheet = "pib")
  pib_year <- extract_year_token(as.character(pib_raw[[1]]))
  pib_value <- as.numeric(pib_raw[[2]])
  pib_keep <- !is.na(pib_year) & pib_year >= 2020 & pib_year <= 2024
  pib_nominal_anual <- stats::aggregate(
    pib_value[pib_keep],
    by = list(year = pib_year[pib_keep]),
    FUN = sum,
    na.rm = TRUE
  )
  names(pib_nominal_anual)[2] <- "pib_nominal"
  pib_nominal_anual$pib_nominal <- pib_nominal_anual$pib_nominal * 1e6
  pib_2025 <- pib_nominal_anual$pib_nominal[nrow(pib_nominal_anual)] * 1.025
  pib_nominal_anual <- rbind(
    pib_nominal_anual,
    data.frame(year = 2025, pib_nominal = pib_2025)
  )

  ipc_raw <- read_required_excel(series_path, sheet = "ipc")
  ipc_year <- as.numeric(ipc_raw[[1]])
  ipc_value <- as.numeric(ipc_raw[[3]])
  ipc_keep <- !is.na(ipc_year) & ipc_year >= 2020 & ipc_year <= 2024
  ipc_anual <- stats::aggregate(
    ipc_value[ipc_keep],
    by = list(year = ipc_year[ipc_keep]),
    FUN = mean,
    na.rm = TRUE
  )
  names(ipc_anual)[2] <- "ipc_promedio_anual"
  ipc_2024 <- ipc_anual$ipc_promedio_anual[ipc_anual$year == 2024]
  ipc_anual$ipc_base_24 <- 100 * ipc_anual$ipc_promedio_anual / ipc_2024
  ipc_anual <- ipc_anual[c("year", "ipc_base_24")]
  ipc_anual <- rbind(
    ipc_anual,
    data.frame(year = 2025, ipc_base_24 = 105.8)
  )

  dolar_raw <- read_required_excel(series_path, sheet = "dolar")
  dolar_date <- parse_legacy_date(dolar_raw[[1]])
  dolar_value <- as.numeric(dolar_raw[[3]])
  dolar_year <- as.integer(format(dolar_date, "%Y"))
  dolar_keep <- !is.na(dolar_year) & dolar_year >= 2020
  dolar_promedio_anual <- stats::aggregate(
    dolar_value[dolar_keep],
    by = list(year = dolar_year[dolar_keep]),
    FUN = mean,
    na.rm = TRUE
  )
  names(dolar_promedio_anual)[2] <- "dolar_promedio"

  list(
    ipc_anual = ipc_anual,
    pib_nominal_anual = pib_nominal_anual,
    dolar_promedio_anual = dolar_promedio_anual
  )
}

build_proyecciones <- function(proyeccion_path, series_path) {
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

  macro <- build_macro_series(series_path)
  year_index <- match(proyecciones$year, macro$ipc_anual$year)
  proyecciones$ejecutado_2024 <- 100 * proyecciones$ejecutado / macro$ipc_anual$ipc_base_24[year_index]

  year_index <- match(proyecciones$year, macro$pib_nominal_anual$year)
  proyecciones$ejecutado_pct_pib <- proyecciones$ejecutado / macro$pib_nominal_anual$pib_nominal[year_index]

  year_index <- match(proyecciones$year, macro$dolar_promedio_anual$year)
  proyecciones$ejecutado_usd <- proyecciones$ejecutado / macro$dolar_promedio_anual$dolar_promedio[year_index]

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
