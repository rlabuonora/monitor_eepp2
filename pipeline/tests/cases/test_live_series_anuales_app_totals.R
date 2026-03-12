run_test("live processed series_anuales matches home-page facet totals for the latest year", {
  series_anuales <- readRDS(project_path("monitor", "data", "processed", "series_anuales.rds"))

  assert_true(is.data.frame(series_anuales), "Processed series_anuales is not a data frame.")
  assert_true(nrow(series_anuales) > 0, "Processed series_anuales is empty.")
  assert_true("year" %in% names(series_anuales), "Processed series_anuales is missing the year column.")
  assert_true("facet_col" %in% names(series_anuales), "Processed series_anuales is missing the facet_col column.")
  assert_true("valor" %in% names(series_anuales), "Processed series_anuales is missing the valor column.")

  latest_year <- max(series_anuales[["year"]], na.rm = TRUE)
  latest_rows <- series_anuales[series_anuales[["year"]] == latest_year, c("facet_col", "valor")]
  actual <- stats::aggregate(
    latest_rows[["valor"]],
    by = list(facet_col = latest_rows[["facet_col"]]),
    FUN = sum
  )
  names(actual)[2] <- "valor"

  expected <- data.frame(
    facet_col = c(
      "Gastos",
      "Impuestos y Transferencias",
      "Ingresos",
      "Inversiones",
      "Resultado"
    ),
    valor = c(
      189146330351,
      -105661177739,
      327757721004,
      24107292517,
      8838604631
    ),
    stringsAsFactors = FALSE
  )

  assert_data_frame_equal(actual, expected, key_cols = "facet_col", tolerance = 1e-6)
})
