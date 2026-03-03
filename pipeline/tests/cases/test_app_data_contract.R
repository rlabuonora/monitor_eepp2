run_test("app required datasets match the manifest contract", {
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(project_path("monitor", "app"))

  source("bootstrap.R", local = TRUE)

  manifest_ids <- vapply(list_required_datasets(), function(entry) entry$id, character(1))
  app_ids <- app_required_dataset_ids()

  assert_setequal(app_ids, manifest_ids, "App dataset ids do not match the manifest contract.")
})

run_test("app runtime has no hidden direct dataset reads outside data_access", {
  app_root <- project_path("monitor", "app")
  app_files <- list.files(app_root, pattern = "[.]R$", full.names = TRUE, recursive = TRUE)
  app_files <- app_files[!grepl("/R/data_access[.]R$", app_files)]

  read_pattern <- "readRDS\\(|read\\.csv\\(|read_csv\\(|read_delim\\(|read_parquet\\(|qread\\(|read_excel\\(|read_xlsx\\("
  offenders <- character()

  for (file in app_files) {
    lines <- readLines(file, warn = FALSE)
    hits <- grep(read_pattern, lines, perl = TRUE)
    if (length(hits) > 0) {
      rel_file <- sub(paste0("^", project_root(), "/"), "", file)
      offenders <- c(offenders, sprintf("%s:%s", rel_file, hits))
    }
  }

  assert_true(
    length(offenders) == 0,
    sprintf("App files still contain direct data reads: %s", paste(offenders, collapse = ", "))
  )
})
