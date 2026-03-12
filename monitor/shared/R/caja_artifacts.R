caja_entes_minimo_ingreso <- function() {
  c("ANP", "ANTEL", "OSE", "URSEA", "URSEC", "UTE")
}

caja_entes_minimo_gasto <- function() {
  c("AFE", "ANCAP", "ANCO", "ANV", "INC")
}

caja_opening_balance_overrides <- function() {
  c(
    ANTEL = 2966359000
  )
}

caja_gastos_minimos_overrides <- function() {
  c(
    AFE = 172474688,
    ANCAP = 21822288449,
    ANCO = 687419343,
    ANP = 837957269,
    ANTEL = 4287138308,
    ANV = 299242798,
    INC = 96049414,
    OSE = 3521200565,
    URSEA = 42319191,
    URSEC = -14122269,
    UTE = 11180550608
  )
}

read_caja_inicial_native <- function(caja_inicial_path, year) {
  raw <- readxl::read_excel(
    caja_inicial_path,
    sheet = "Caja",
    range = "A1:D12",
    .name_repair = "minimal"
  )

  names(raw) <- c("empresa", "saldo_inicial_miles", "caja_mes", "minima")
  overrides <- caja_opening_balance_overrides()

  raw |>
    dplyr::transmute(
      empresa = .data$empresa,
      saldo = dplyr::coalesce(
        1e3 * .data$saldo_inicial_miles,
        unname(overrides[.data$empresa])
      ),
      fecha = as.Date(sprintf("%d-01-01", year))
    )
}

build_caja_mensual_native <- function(monitor_dir, ejecucion_mensual) {
  latest_year <- max(ejecucion_mensual$year, na.rm = TRUE)
  previous_year <- latest_year - 1L
  caja_inicial_path <- monitor_path("data", "raw", "caja_inicial.xlsx", monitor_dir = monitor_dir)
  assert_file_exists(caja_inicial_path)

  caja_inicial <- read_caja_inicial_native(caja_inicial_path, latest_year)

  caja_movimientos <- ejecucion_mensual |>
    dplyr::filter(
      .data$year == latest_year,
      .data$header_code == "I",
      .data$sub_header_code == 5,
      .data$item_code == 1
    ) |>
    dplyr::transmute(
      header_code = .data$header_code,
      sub_header_code = .data$sub_header_code,
      item_code = .data$item_code,
      empresa = .data$empresa,
      fecha = as.Date(sprintf("%d-%02d-01", .data$year, .data$month)),
      valor = 1e3 * .data$valor
    )

  saldo_minimo_ingresos <- ejecucion_mensual |>
    dplyr::filter(
      .data$year == previous_year,
      .data$header_code == "A",
      is.na(.data$sub_header_code),
      is.na(.data$item_code)
    ) |>
    dplyr::group_by(.data$empresa) |>
    dplyr::summarise(saldo_minimo_ingresos = sum(.data$valor) / 12, .groups = "drop")

  gastos_minimos_pesos <- caja_gastos_minimos_overrides()
  saldo_minimo_gastos <- data.frame(
    empresa = names(gastos_minimos_pesos),
    saldo_minimo_gastos = as.numeric(gastos_minimos_pesos) / 1e3,
    stringsAsFactors = FALSE
  )

  caja_movimientos |>
    dplyr::left_join(caja_inicial, by = c("empresa", "fecha")) |>
    dplyr::arrange(.data$empresa, .data$fecha) |>
    dplyr::group_by(.data$empresa) |>
    dplyr::mutate(
      saldo_initial = dplyr::first(.data$saldo[!is.na(.data$saldo)]),
      valor_cum = cumsum(dplyr::coalesce(.data$valor, 0)),
      saldo_calc = .data$saldo_initial - .data$valor_cum,
      saldo = dplyr::if_else(lubridate::month(.data$fecha) == 1, .data$saldo, .data$saldo_calc)
    ) |>
    dplyr::ungroup() |>
    dplyr::select("header_code", "sub_header_code", "item_code", "empresa", "fecha", "saldo") |>
    dplyr::left_join(saldo_minimo_gastos, by = "empresa") |>
    dplyr::left_join(saldo_minimo_ingresos, by = "empresa") |>
    dplyr::mutate(
      saldo_minimo = dplyr::case_when(
        .data$empresa %in% caja_entes_minimo_ingreso() ~ .data$saldo_minimo_ingresos,
        .data$empresa %in% caja_entes_minimo_gasto() ~ .data$saldo_minimo_gastos,
        TRUE ~ NA_real_
      ),
      saldo_minimo = 1e3 * .data$saldo_minimo
    ) |>
    dplyr::select(
      "header_code", "sub_header_code", "item_code", "empresa",
      "saldo", "saldo_minimo_gastos", "saldo_minimo_ingresos", "saldo_minimo", "fecha"
    ) |>
    dplyr::as_tibble()
}
