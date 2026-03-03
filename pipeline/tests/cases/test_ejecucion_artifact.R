run_test("ejecucion_mensual fixture has expected intermediate schema", {
  ejecucion_mensual <- load_rda_object(
    project_path("pipeline", "fixtures", "ejecucion_mensual.rda"),
    "ejecucion_mensual"
  )

  expected_cols <- c(
    "row", "empresa", "header_code", "sub_header_code", "item_code",
    "valor", "month", "year"
  )

  assert_true(is.data.frame(ejecucion_mensual), "ejecucion_mensual is not a data frame.")
  assert_true(nrow(ejecucion_mensual) > 0, "ejecucion_mensual is empty.")
  assert_setequal(names(ejecucion_mensual), expected_cols, "ejecucion_mensual schema is missing required columns.")
  assert_setequal(unique(ejecucion_mensual$month), 1:12, "ejecucion_mensual months are incomplete.")
  assert_setequal(unique(ejecucion_mensual$year), 2020:2025, "ejecucion_mensual years are unexpected.")
})

run_test("ejecucion_mensual 2024 header totals match the migration fixture", {
  ejecucion_mensual <- load_rda_object(
    project_path("pipeline", "fixtures", "ejecucion_mensual.rda"),
    "ejecucion_mensual"
  )
  expected <- utils::read.csv(
    project_path("pipeline", "fixtures", "ejecucion_mensual_2024_header_totals.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  mask <- ejecucion_mensual$year == 2024 &
    !is.na(ejecucion_mensual$header_code) &
    is.na(ejecucion_mensual$sub_header_code) &
    is.na(ejecucion_mensual$item_code)

  actual <- aggregate(valor ~ header_code, ejecucion_mensual[mask, ], sum)
  assert_data_frame_equal(actual, expected, key_cols = "header_code", tolerance = 1e-6)
})

run_test("ejecucion_mensual 2025 header totals match the migration fixture", {
  ejecucion_mensual <- load_rda_object(
    project_path("pipeline", "fixtures", "ejecucion_mensual.rda"),
    "ejecucion_mensual"
  )
  expected <- utils::read.csv(
    project_path("pipeline", "fixtures", "ejecucion_mensual_2025_header_totals.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  mask <- ejecucion_mensual$year == 2025 &
    !is.na(ejecucion_mensual$header_code) &
    is.na(ejecucion_mensual$sub_header_code) &
    is.na(ejecucion_mensual$item_code)

  actual <- aggregate(valor ~ header_code, ejecucion_mensual[mask, ], sum)
  assert_data_frame_equal(actual, expected, key_cols = "header_code", tolerance = 1e-6)
})

run_test("legacy import_ejecucion fallback branch loads the fixture artifact without package install", {
  legacy_impl <- project_path("legacy", "eeppImport", "R", "import_ejecucion.R")
  temp_root <- tempfile("ejecucion_test_")
  dir.create(temp_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(temp_root, "data"), recursive = TRUE, showWarnings = FALSE)

  fixture_path <- project_path("pipeline", "fixtures", "ejecucion_mensual.rda")
  file.copy(fixture_path, file.path(temp_root, "data", "ejecucion_mensual.rda"), overwrite = TRUE)

  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(temp_root)

  lines <- readLines(legacy_impl, warn = FALSE)
  lines <- lines[!grepl('utils::data("ejecucion_mensual", package = "eeppImport"', lines, fixed = TRUE)]
  eval(parse(text = paste(lines, collapse = "\n")), envir = environment())
  loaded <- import_ejecucion()

  assert_true(is.data.frame(loaded), "import_ejecucion() did not return a data frame.")
  assert_true(nrow(loaded) > 0, "import_ejecucion() returned no rows.")
  assert_setequal(names(loaded), c("row", "empresa", "header_code", "sub_header_code", "item_code", "valor", "month", "year"), "import_ejecucion() returned an unexpected schema.")
  assert_setequal(unique(loaded$month), 1:12, "import_ejecucion() returned incomplete months.")
})
