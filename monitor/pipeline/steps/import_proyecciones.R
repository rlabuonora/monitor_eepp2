run_import_proyecciones <- function(monitor_dir) {
  raw_dir <- monitor_path("data", "raw", monitor_dir = monitor_dir)
  interim_dir <- monitor_path("data", "interim", monitor_dir = monitor_dir)
  processed_dir <- monitor_path("data", "processed", monitor_dir = monitor_dir)

  ensure_dir(raw_dir)
  ensure_dir(interim_dir)
  ensure_dir(processed_dir)

  proyeccion_path <- file.path(raw_dir, "proyeccion.xlsx")
  output_path <- file.path(processed_dir, "proyecciones.rds")

  proyecciones <- build_proyecciones(
    proyeccion_path = proyeccion_path,
    raw_dir = raw_dir
  )

  saveRDS(proyecciones, output_path)

  message("Imported dataset: proyecciones")
  message("Wrote: ", output_path)

  invisible(output_path)
}
