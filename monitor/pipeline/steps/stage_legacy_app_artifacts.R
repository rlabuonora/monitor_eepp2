read_single_rda_object <- function(path, object_name = NULL) {
  env <- new.env(parent = emptyenv())
  loaded_names <- load(path, envir = env)

  if (length(loaded_names) == 0) {
    stop(sprintf("No objects found in %s", path), call. = FALSE)
  }

  if (is.null(object_name)) {
    if (length(loaded_names) != 1) {
      stop(
        sprintf("Expected exactly one object in %s, found: %s", path, paste(loaded_names, collapse = ", ")),
        call. = FALSE
      )
    }
    object_name <- loaded_names[[1]]
  }

  if (!exists(object_name, envir = env, inherits = FALSE)) {
    stop(sprintf("Object '%s' not found in %s", object_name, path), call. = FALSE)
  }

  get(object_name, envir = env, inherits = FALSE)
}

copy_legacy_rds <- function(source_path, target_path) {
  assert_file_exists(source_path)

  ok <- file.copy(source_path, target_path, overwrite = TRUE)
  if (!isTRUE(ok)) {
    stop(sprintf("Failed to stage legacy artifact to %s", target_path), call. = FALSE)
  }

  message("Staged legacy artifact: ", target_path)
}

write_macro_artifact <- function(series_macro_path, object_name, target_path) {
  object <- read_single_rda_object(series_macro_path, object_name)
  saveRDS(object, target_path)
  message("Wrote legacy macro artifact: ", target_path)
}

stage_legacy_app_artifacts <- function(repo_root, monitor_dir) {
  processed_dir <- monitor_path("data", "processed", monitor_dir = monitor_dir)
  ensure_dir(processed_dir)

  legacy_app_data_dir <- file.path(repo_root, "legacy", "monitor_eepp", "data")
  legacy_pkg_data_dir <- file.path(repo_root, "legacy", "eeppImport", "data")
  series_macro_path <- file.path(legacy_pkg_data_dir, "series_macro.rda")

  copy_legacy_rds(
    file.path(legacy_app_data_dir, "series_anuales.rds"),
    file.path(processed_dir, "series_anuales.rds")
  )
  copy_legacy_rds(
    file.path(legacy_app_data_dir, "series_mensuales.rds"),
    file.path(processed_dir, "series_mensuales.rds")
  )
  copy_legacy_rds(
    file.path(legacy_app_data_dir, "caja_mensual.rds"),
    file.path(processed_dir, "caja_mensual.rds")
  )

  write_macro_artifact(
    series_macro_path,
    "ipc_anual_24",
    file.path(processed_dir, "serie_ipc_anual_24.rds")
  )
  write_macro_artifact(
    series_macro_path,
    "pib_nominal_anual",
    file.path(processed_dir, "serie_pib_anual.rds")
  )
  write_macro_artifact(
    series_macro_path,
    "dolar_promedio_anual",
    file.path(processed_dir, "dolar_promedio_anual.rds")
  )

  invisible(TRUE)
}
