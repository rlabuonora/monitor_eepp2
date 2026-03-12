clean_monitor_excel_names <- function(df) {
  cleaned_names <- names(df)
  cleaned_names <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", cleaned_names)
  cleaned_names <- tolower(cleaned_names)
  cleaned_names <- gsub("[^a-z0-9]+", "_", cleaned_names)
  cleaned_names <- gsub("^_|_$", "", cleaned_names)
  stats::setNames(df, cleaned_names)
}

required_series_source_filenames <- function() {
  c(
    sprintf("%d.xlsx", 2020:2025),
    "estructura2.xlsx",
    "firmados.xlsx",
    "series.xlsx"
  )
}

assert_required_series_sources <- function(monitor_dir) {
  invisible(lapply(required_series_source_filenames(), function(filename) {
    assert_file_exists(monitor_path("data", "raw", filename, monitor_dir = monitor_dir))
  }))
}

build_estructura_maps <- function(estructura_path) {
  estructura_map <- readxl::read_excel(
    path = estructura_path,
    sheet = "ejecutado",
    range = "A1:E84",
    .name_repair = "minimal"
  ) |>
    dplyr::select(-1) |>
    dplyr::mutate(row = 6 + dplyr::row_number()) |>
    dplyr::relocate(row) |>
    clean_monitor_excel_names() |>
    dplyr::rename(
      header_code = header,
      sub_header_code = sub_header,
      item_code = item
    ) |>
    dplyr::select(row, header_code, sub_header_code, item_code, label_estructura = label)

  estructura_empresa_wide <- readxl::read_excel(
    path = estructura_path,
    sheet = "ejecutado",
    range = "B1:P84",
    .name_repair = "minimal"
  ) |>
    dplyr::select(-Label)

  empresa_cols <- setdiff(names(estructura_empresa_wide), c("Header", "SubHeader", "Item"))
  estructura_map_empresa <- dplyr::bind_rows(lapply(empresa_cols, function(empresa_col) {
    data.frame(
      Header = estructura_empresa_wide$Header,
      SubHeader = estructura_empresa_wide$SubHeader,
      Item = estructura_empresa_wide$Item,
      empresa = empresa_col,
      rubro = estructura_empresa_wide[[empresa_col]],
      stringsAsFactors = FALSE
    )
  })) |>
    clean_monitor_excel_names() |>
    dplyr::rename(
      header_code = header,
      sub_header_code = sub_header,
      item_code = item
    ) |>
    dplyr::filter(!(is.na(.data$header_code) & is.na(.data$sub_header_code) & is.na(.data$item_code))) |>
    dplyr::select(header_code, sub_header_code, item_code, empresa, rubro)

  list(
    estructura_map = estructura_map,
    estructura_map_empresa = estructura_map_empresa
  )
}

import_ejecucion_archivo <- function(path, estructura_map,
                                     sheets = c("ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SET", "OCT", "NOV", "DIC"),
                                     range = "A6:J89") {
  if (!requireNamespace("tidyxl", quietly = TRUE)) {
    stop("Package 'tidyxl' is required.", call. = FALSE)
  }
  if (!requireNamespace("cellranger", quietly = TRUE)) {
    stop("Package 'cellranger' is required.", call. = FALSE)
  }

  sheets_data <- lapply(sheets, function(sheet) {
    limits <- cellranger::as.cell_limits(range)
    cells <- tidyxl::xlsx_cells(path, sheets = sheet) |>
      dplyr::filter(
        .data$row >= limits$ul[1],
        .data$row <= limits$lr[1],
        .data$col >= limits$ul[2],
        .data$col <= limits$lr[2]
      )

    empresas <- cells |>
      dplyr::filter(.data$row == limits$ul[1], !is.na(.data$character), .data$character != "") |>
      dplyr::select(col, empresa = character)

    labels <- cells |>
      dplyr::filter(.data$col == 1, !is.na(.data$character)) |>
      dplyr::transmute(row, label = character) |>
      dplyr::left_join(estructura_map, by = "row")

    valores <- cells |>
      dplyr::filter(!is.na(.data$numeric))

    valores |>
      dplyr::left_join(empresas, by = "col") |>
      dplyr::left_join(labels, by = "row") |>
      dplyr::transmute(
        row,
        empresa,
        header_code,
        sub_header_code,
        item_code,
        label,
        valor = numeric,
        month = sheet
      )
  })

  dplyr::bind_rows(sheets_data)
}

build_ejecucion_mensual_native <- function(monitor_dir, estructura_map) {
  month_levels <- c("ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SET", "OCT", "NOV", "DIC")
  years <- 2020:2025

  dplyr::bind_rows(lapply(years, function(year) {
    path <- monitor_path("data", "raw", sprintf("%d.xlsx", year), monitor_dir = monitor_dir)
    assert_file_exists(path)
    range <- if (year >= 2024) "A6:L89" else "A6:J89"

    import_ejecucion_archivo(
      path = path,
      estructura_map = estructura_map,
      range = range
    ) |>
      dplyr::mutate(year = year)
  })) |>
    dplyr::mutate(month = match(.data$month, month_levels)) |>
    dplyr::select(-label)
}

firmado_empresas_default <- function() {
  c("AFE", "ANCAP", "ANCO", "ANP", "ANTEL", "ANV", "INC", "OSE", "UTE", "URSEC", "URSEA")
}

firmado_meses_default <- function() {
  c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "setiembre", "octubre", "noviembre", "diciembre")
}

build_firmado_raw_native <- function(path, estructura_map_empresa, hojas = firmado_empresas_default(), range = "A1:P66", year = 2025L) {
  hojas <- unique(hojas)
  meses <- firmado_meses_default()

  importar_hoja <- function(hoja) {
    hoja_raw <- readxl::read_excel(path, range = range, sheet = hoja) |>
      clean_monitor_excel_names() |>
      dplyr::filter(!is.na(.data$header)) |>
      dplyr::relocate(header, sub_header, item, .after = concepto)

    month_cols <- setdiff(names(hoja_raw), c("concepto", "header", "sub_header", "item"))
    dplyr::bind_rows(lapply(month_cols, function(month_col) {
      data.frame(
        concepto = hoja_raw$concepto,
        header = hoja_raw$header,
        sub_header = hoja_raw$sub_header,
        item = hoja_raw$item,
        mes = month_col,
        firmado = hoja_raw[[month_col]],
        stringsAsFactors = FALSE
      )
    })) |>
      dplyr::mutate(
        mes = match(.data$mes, meses),
        empresa = hoja,
        valor = 1e3 * .data$firmado,
        fecha = as.Date(sprintf("%d-%02d-01", year, .data$mes)),
        label_excel = .data$concepto
      ) |>
      dplyr::select(
        empresa,
        fecha,
        header_code = header,
        sub_header_code = sub_header,
        item_code = item,
        label_excel,
        valor
      )
  }

  labels_map <- estructura_map_empresa |>
    dplyr::transmute(
      empresa = .data$empresa,
      header_code = .data$header_code,
      sub_header_code = .data$sub_header_code,
      item_code = .data$item_code,
      label = .data$rubro
    )

  dplyr::bind_rows(lapply(hojas, importar_hoja)) |>
    dplyr::group_by(.data$empresa, .data$fecha, .data$header_code, .data$sub_header_code, .data$item_code) |>
    dplyr::summarise(
      valor = sum(.data$valor, na.rm = TRUE),
      label_excel = dplyr::first(.data$label_excel[!is.na(.data$label_excel)]),
      .groups = "drop"
    ) |>
    dplyr::left_join(labels_map, by = c("empresa", "header_code", "sub_header_code", "item_code")) |>
    dplyr::mutate(label = dplyr::coalesce(.data$label, .data$label_excel)) |>
    dplyr::select("empresa", "header_code", "sub_header_code", "item_code", "label", "fecha", "valor")
}

build_firmado_mensual_native <- function(firmado_raw) {
  firmado_mensual <- firmado_raw |>
    dplyr::filter(!is.na(.data$header_code), !is.na(.data$sub_header_code), !is.na(.data$item_code)) |>
    dplyr::filter(.data$header_code %in% c("A", "B", "D", "F", "H")) |>
    dplyr::mutate(
      fill_col = dplyr::case_when(
        .data$header_code == "A" ~ "Ingresos",
        .data$header_code == "B" & .data$sub_header_code == 1 ~ "Sueldos",
        .data$header_code == "B" & .data$sub_header_code == 2 ~ "Compras",
        .data$header_code == "B" & .data$sub_header_code == 3 ~ "Intereses",
        .data$header_code == "D" & .data$item_code %in% c(1, 2, 3, 6, 7, 8, 9, 10, 11) ~ "Impuestos",
        .data$header_code == "D" & .data$item_code == 4 ~ "BPS",
        .data$header_code == "D" & .data$item_code == 5 ~ "Transferencias",
        .data$header_code == "H" ~ "Resultado",
        .data$header_code == "F" & .data$item_code == 3 & .data$empresa == "ANCAP" ~ "Variación de Stocks",
        .data$header_code == "F" ~ "Formación de Capital"
      ),
      facet_col = dplyr::case_when(
        .data$header_code == "A" ~ "Ingresos",
        .data$header_code == "B" ~ "Gastos",
        .data$header_code == "D" ~ "Impuestos y Transferencias",
        .data$header_code == "H" ~ "Resultado",
        .data$header_code == "F" ~ "Inversiones"
      )
    ) |>
    dplyr::filter(!is.na(.data$fill_col), !is.na(.data$facet_col))

  bad_label <- is.na(firmado_mensual$label) | trimws(as.character(firmado_mensual$label)) == ""
  if (any(bad_label)) {
    stop("build_firmado_mensual_native(): found rows with missing/blank label.", call. = FALSE)
  }

  firmado_mensual |>
    dplyr::select("fecha", "label", "empresa", "facet_col", "fill_col", "valor", "header_code", "sub_header_code", "item_code")
}

normalize_series_mensuales_code_keys <- function(df) {
  has_codes <- all(c("header_code", "sub_header_code", "item_code") %in% names(df))
  if (!has_codes) {
    return(df)
  }

  is_h <- !is.na(df$header_code) & df$header_code == "H"
  is_af_na_agg <- !is.na(df$header_code) & df$header_code %in% c("A", "F") & is.na(df$sub_header_code) & is.na(df$item_code)
  is_f_zero_agg <- !is.na(df$header_code) & df$header_code == "F" & !is.na(df$item_code) & df$item_code == 0
  needs_zero_zero <- is_h | is_af_na_agg | is_f_zero_agg

  dplyr::mutate(
    df,
    sub_header_code = dplyr::if_else(needs_zero_zero, 0, .data$sub_header_code),
    item_code = dplyr::if_else(needs_zero_zero, 0, .data$item_code)
  )
}

filter_ejecucion_mensual_to_firmado_keys <- function(ejecucion_mensual, firmado_rows) {
  required <- c("empresa", "year", "month", "header_code", "sub_header_code", "item_code")
  if (!all(required %in% names(firmado_rows))) {
    return(ejecucion_mensual)
  }

  firmado_keys <- normalize_series_mensuales_code_keys(firmado_rows) |>
    dplyr::distinct(.data$empresa, .data$year, .data$month, .data$header_code, .data$sub_header_code, .data$item_code)

  normalize_series_mensuales_code_keys(ejecucion_mensual) |>
    dplyr::semi_join(firmado_keys, by = required)
}

classify_series_mensuales_rows <- function(df) {
  df |>
    dplyr::mutate(
      fill_col = dplyr::case_when(
        header_code == "A" ~ "Ingresos",
        header_code == "B" & sub_header_code == 1 ~ "Sueldos",
        header_code == "B" & sub_header_code == 2 ~ "Compras",
        header_code == "B" & sub_header_code == 3 ~ "Intereses",
        header_code == "D" & item_code %in% c(1, 2, 3, 6, 7, 8, 9, 10, 11) ~ "Impuestos",
        header_code == "D" & item_code == 4 ~ "BPS",
        header_code == "D" & item_code == 5 ~ "Transferencias",
        header_code == "H" ~ "Resultado",
        header_code == "F" & item_code == 3 & empresa == "ANCAP" ~ "Variación de Stocks",
        header_code == "F" ~ "Formación de Capital"
      ),
      facet_col = dplyr::case_when(
        header_code == "A" ~ "Ingresos",
        header_code == "B" ~ "Gastos",
        header_code == "D" ~ "Impuestos y Transferencias",
        header_code == "H" ~ "Resultado",
        header_code == "F" ~ "Inversiones"
      )
    ) |>
    dplyr::filter(!is.na(.data$fill_col), !is.na(.data$facet_col))
}

build_series_mensuales_label_map <- function(estructura_map_empresa) {
  label_col <- if ("label" %in% names(estructura_map_empresa)) "label" else "rubro"

  label_map <- estructura_map_empresa |>
    dplyr::transmute(
      empresa = .data$empresa,
      header_code = .data$header_code,
      sub_header_code = .data$sub_header_code,
      item_code = .data$item_code,
      label = .data[[label_col]]
    ) |>
    normalize_series_mensuales_code_keys()

  dup_keys <- label_map |>
    dplyr::count(.data$empresa, .data$header_code, .data$sub_header_code, .data$item_code) |>
    dplyr::filter(.data$n > 1)

  if (nrow(dup_keys) > 0) {
    stop("estructura_map_empresa has duplicate keys after normalization.", call. = FALSE)
  }

  label_map
}

canonicalize_series_mensuales_label <- function(label) {
  label_chr <- trimws(as.character(label))
  label_chr <- gsub("\\s+", " ", label_chr)

  dplyr::case_when(
    tolower(label_chr) == "otros ingresos" ~ "Otros Ingresos",
    TRUE ~ label_chr
  )
}

standardize_series_mensuales_source <- function(df, tipo, label_map, valor_multiplier = 1) {
  out <- df |>
    normalize_series_mensuales_code_keys() |>
    classify_series_mensuales_rows() |>
    dplyr::left_join(label_map, by = c("empresa", "header_code", "sub_header_code", "item_code")) |>
    dplyr::mutate(label = canonicalize_series_mensuales_label(.data$label))

  bad_label <- is.na(out$label) | trimws(as.character(out$label)) == ""
  if (any(bad_label)) {
    stop(sprintf("%s has classified rows with missing labels.", tipo), call. = FALSE)
  }

  out |>
    dplyr::mutate(valor = valor_multiplier * .data$valor, tipo = tipo) |>
    dplyr::select("empresa", "facet_col", "fill_col", "label", "year", "month", "valor", "tipo", "header_code", "sub_header_code", "item_code") |>
    dplyr::distinct()
}

build_series_anuales_native <- function(ejecucion_mensual, macro_series) {
  ipc_anual <- macro_series$ipc_anual
  pib_nominal_anual <- macro_series$pib_nominal_anual

  dplyr::bind_rows(
    dplyr::filter(ejecucion_mensual, header_code == "A", is.na(sub_header_code), is.na(item_code)),
    dplyr::filter(ejecucion_mensual, header_code == "B", !is.na(sub_header_code), !is.na(item_code), item_code != 0),
    dplyr::filter(ejecucion_mensual, header_code == "H", sub_header_code == 1),
    dplyr::filter(ejecucion_mensual, header_code == "D", !is.na(sub_header_code), !is.na(item_code), item_code != 0),
    dplyr::filter(ejecucion_mensual, header_code == "F", !is.na(sub_header_code), !is.na(item_code), item_code != 0)
  ) |>
    dplyr::mutate(
      fill_col = dplyr::case_when(
        header_code == "A" ~ "Ingresos",
        header_code == "B" & sub_header_code == 1 ~ "Sueldos",
        header_code == "B" & sub_header_code == 2 ~ "Compras",
        header_code == "B" & sub_header_code == 3 ~ "Intereses",
        header_code == "D" & item_code %in% c(1, 2, 3, 6, 7, 8, 9, 10, 11) ~ "Impuestos",
        header_code == "D" & item_code == 4 ~ "BPS",
        header_code == "D" & item_code == 5 ~ "Transferencias",
        header_code == "H" ~ "Resultado",
        header_code == "F" & item_code == 3 & empresa == "ANCAP" ~ "Variación de Stocks",
        header_code == "F" ~ "Formación de Capital"
      ),
      facet_col = dplyr::case_when(
        header_code == "A" ~ "Ingresos",
        header_code == "B" ~ "Gastos",
        header_code == "D" ~ "Impuestos y Transferencias",
        header_code == "H" ~ "Resultado",
        header_code == "F" ~ "Inversiones"
      ),
      valor = 1e3 * .data$valor
    ) |>
    dplyr::group_by(.data$empresa, .data$year, .data$facet_col, .data$fill_col) |>
    dplyr::summarise(valor = sum(.data$valor), .groups = "drop") |>
    dplyr::left_join(ipc_anual, by = "year") |>
    dplyr::left_join(pib_nominal_anual, by = "year") |>
    dplyr::left_join(macro_series$dolar_promedio_anual, by = "year") |>
    dplyr::mutate(
      valor_2024 = 100 * .data$valor / .data$ipc_base_24,
      valor_pct_pib = .data$valor / .data$pib_nominal,
      valor_usd = .data$valor / .data$dolar_promedio
    ) |>
    dplyr::select("empresa", "year", "facet_col", "fill_col", "valor", "valor_2024", "valor_pct_pib", "valor_usd")
}

build_series_mensuales_native <- function(ejecucion_mensual, firmado_raw, estructura_map_empresa) {
  firmado_rows <- firmado_raw |>
    dplyr::mutate(
      year = as.integer(format(.data$fecha, "%Y")),
      month = as.integer(format(.data$fecha, "%m"))
    ) |>
    dplyr::select("empresa", "header_code", "sub_header_code", "item_code", "year", "month", "valor")

  label_map <- build_series_mensuales_label_map(estructura_map_empresa)
  ejecucion_filtered <- filter_ejecucion_mensual_to_firmado_keys(ejecucion_mensual, firmado_rows)

  df_firmado <- standardize_series_mensuales_source(firmado_rows, "Firmado", label_map, valor_multiplier = 1)
  df_ejecutado <- standardize_series_mensuales_source(ejecucion_filtered, "Ejecutado", label_map, valor_multiplier = 1e3)

  dplyr::bind_rows(df_ejecutado, df_firmado) |>
    dplyr::mutate(fecha = as.Date(sprintf("%d-%02d-01", .data$year, .data$month))) |>
    dplyr::select("fecha", "empresa", "facet_col", "fill_col", "label", "valor", "tipo", "header_code", "sub_header_code", "item_code")
}

build_native_series_artifacts <- function(monitor_dir) {
  assert_required_series_sources(monitor_dir)

  estructura_path <- monitor_path("data", "raw", "estructura2.xlsx", monitor_dir = monitor_dir)
  series_path <- monitor_path("data", "raw", "series.xlsx", monitor_dir = monitor_dir)
  firmado_path <- monitor_path("data", "raw", "firmados.xlsx", monitor_dir = monitor_dir)

  maps <- build_estructura_maps(estructura_path)
  ejecucion_mensual <- build_ejecucion_mensual_native(monitor_dir, maps$estructura_map)
  latest_year <- max(ejecucion_mensual$year, na.rm = TRUE)
  firmado_raw <- build_firmado_raw_native(firmado_path, maps$estructura_map_empresa, year = latest_year)
  firmado_mensual <- build_firmado_mensual_native(firmado_raw)
  macro_series <- build_macro_series(series_path)

  list(
    estructura_map = maps$estructura_map,
    estructura_map_empresa = maps$estructura_map_empresa,
    ejecucion_mensual = ejecucion_mensual,
    firmado_raw = firmado_raw,
    firmado_mensual = firmado_mensual,
    series_anuales = build_series_anuales_native(ejecucion_mensual, macro_series),
    series_mensuales = build_series_mensuales_native(ejecucion_mensual, firmado_raw, maps$estructura_map_empresa),
    macro_series = macro_series
  )
}
