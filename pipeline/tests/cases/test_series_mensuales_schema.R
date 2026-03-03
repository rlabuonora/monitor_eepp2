run_test("series_mensuales fixture has expected final schema", {
  series_mensuales <- load_rda_object(
    project_path("pipeline", "fixtures", "series_mensuales.rda"),
    "series_mensuales"
  )

  expected_cols <- c(
    "fecha", "empresa", "facet_col", "fill_col", "label", "valor", "tipo",
    "header_code", "sub_header_code", "item_code"
  )

  assert_true(is.data.frame(series_mensuales), "series_mensuales is not a data frame.")
  assert_true(nrow(series_mensuales) > 0, "series_mensuales is empty.")
  assert_setequal(names(series_mensuales), expected_cols, "series_mensuales schema is missing required columns.")
  assert_true(inherits(series_mensuales$fecha, "Date"), "series_mensuales$fecha is not a Date.")
  assert_true(!("year" %in% names(series_mensuales)), "series_mensuales should not expose a year column.")
  assert_true(!("month" %in% names(series_mensuales)), "series_mensuales should not expose a month column.")
  assert_setequal(unique(as.character(series_mensuales$tipo)), c("Ejecutado", "Firmado"), "series_mensuales$tipo values changed.")
})

run_test("series_mensuales fixture remains unique at the join-safe grain", {
  series_mensuales <- load_rda_object(
    project_path("pipeline", "fixtures", "series_mensuales.rda"),
    "series_mensuales"
  )

  key_cols <- c(
    "fecha", "empresa", "facet_col", "fill_col", "label", "tipo",
    "header_code", "sub_header_code", "item_code"
  )

  key_frame <- series_mensuales[key_cols]
  assert_true(anyDuplicated(key_frame) == 0, "series_mensuales has duplicate rows at the expected key grain.")
})
