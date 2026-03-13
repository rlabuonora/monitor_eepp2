copy_legacy_rds <- function(source_path, target_path) {
  assert_file_exists(source_path)

  ok <- file.copy(source_path, target_path, overwrite = TRUE)
  if (!isTRUE(ok)) {
    stop(sprintf("Failed to stage legacy artifact to %s", target_path), call. = FALSE)
  }

  message("Staged legacy artifact: ", target_path)
}

write_processed_rds <- function(object, target_path, label) {
  saveRDS(object, target_path, compress = "xz")
  message("Wrote ", label, ": ", target_path)
}

prepare_dashboard_series_mensuales <- function(series_mensuales) {
  series_mensuales |>
    dplyr::mutate(
      keep = dplyr::case_when(
        .data$header_code == "A" ~
          (.data$sub_header_code == 1 & .data$item_code == 0) |
          (.data$sub_header_code == 2 & .data$item_code == 0),
        .data$header_code == "B" ~
          (.data$sub_header_code == 1 & .data$item_code == 0) |
          (.data$sub_header_code == 2 & .data$item_code != 0) |
          (.data$sub_header_code == 3 & .data$item_code == 0),
        .data$header_code == "F" ~
          (.data$empresa == "ANCAP" & .data$sub_header_code != 0) |
          (.data$empresa != "ANCAP" & .data$sub_header_code == 0),
        TRUE ~ TRUE
      ),
      label = dplyr::if_else(.data$facet_col == "Resultado", "Resultado", .data$label)
    ) |>
    dplyr::filter(.data$keep) |>
    dplyr::filter(abs(.data$valor) > 1)
}

stage_legacy_app_artifacts <- function(repo_root, monitor_dir) {
  processed_dir <- monitor_path("data", "processed", monitor_dir = monitor_dir)
  ensure_dir(processed_dir)

  native_artifacts <- build_native_series_artifacts(monitor_dir = monitor_dir)
  caja_mensual <- build_caja_mensual_native(
    monitor_dir = monitor_dir,
    ejecucion_mensual = native_artifacts$ejecucion_mensual
  )

  write_processed_rds(
    native_artifacts$series_anuales,
    file.path(processed_dir, "series_anuales.rds"),
    "series_anuales"
  )
  write_processed_rds(
    prepare_dashboard_series_mensuales(native_artifacts$series_mensuales),
    file.path(processed_dir, "series_mensuales.rds"),
    "series_mensuales"
  )
  write_processed_rds(caja_mensual, file.path(processed_dir, "caja_mensual.rds"), "caja_mensual")

  write_processed_rds(native_artifacts$macro_series$ipc_anual, file.path(processed_dir, "serie_ipc_anual_24.rds"), "serie_ipc_anual_24")
  write_processed_rds(native_artifacts$macro_series$pib_nominal_anual, file.path(processed_dir, "serie_pib_anual.rds"), "serie_pib_anual")
  write_processed_rds(native_artifacts$macro_series$dolar_promedio_anual, file.path(processed_dir, "dolar_promedio_anual.rds"), "dolar_promedio_anual")

  invisible(TRUE)
}
