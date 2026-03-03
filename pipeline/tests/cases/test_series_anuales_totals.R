run_test("series_anuales fixture has expected structure", {
  series_anuales <- load_rda_object(
    project_path("pipeline", "fixtures", "series_anuales.rda"),
    "series_anuales"
  )

  expected_cols <- c("empresa", "year", "facet_col", "fill_col", "valor", "valor_2024", "valor_pct_pib", "valor_usd")

  assert_true(is.data.frame(series_anuales), "series_anuales is not a data frame.")
  assert_true(nrow(series_anuales) > 0, "series_anuales is empty.")
  assert_setequal(names(series_anuales), expected_cols, "series_anuales schema is missing required columns.")
  assert_true(all(series_anuales$year %in% 2020:2025), "series_anuales contains unexpected years.")
})

run_test("series_anuales 2024 totals match the migration fixture", {
  series_anuales <- load_rda_object(
    project_path("pipeline", "fixtures", "series_anuales.rda"),
    "series_anuales"
  )
  expected <- utils::read.csv(
    project_path("pipeline", "fixtures", "series_anuales_2024_totals.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  actual <- aggregate(valor ~ facet_col, series_anuales[series_anuales$year == 2024, ], sum)
  assert_data_frame_equal(actual, expected, key_cols = "facet_col", tolerance = 1e-6)
})

run_test("series_anuales AFE 2025 fill totals match the migration fixture", {
  series_anuales <- load_rda_object(
    project_path("pipeline", "fixtures", "series_anuales.rda"),
    "series_anuales"
  )
  expected <- utils::read.csv(
    project_path("pipeline", "fixtures", "series_anuales_afe_2025_fill_totals.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  mask <- series_anuales$empresa == "AFE" &
    series_anuales$year == 2025 &
    series_anuales$fill_col %in% c("Ingresos", "Sueldos", "Compras")

  actual <- aggregate(valor ~ fill_col, series_anuales[mask, ], sum)
  assert_data_frame_equal(actual, expected, key_cols = "fill_col", tolerance = 1e-6)
})
