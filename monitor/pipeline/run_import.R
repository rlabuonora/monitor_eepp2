resolve_script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) == 0) {
    stop("run_import.R must be executed with Rscript or R --file.", call. = FALSE)
  }

  normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)
}

script_path <- resolve_script_path()
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
monitor_dir <- file.path(repo_root, "monitor")

Sys.setenv(TZ = Sys.getenv("TZ", unset = "UTC"))

source(file.path(repo_root, "monitor", "shared", "R", "paths.R"), local = TRUE)
source(file.path(repo_root, "monitor", "shared", "R", "utils.R"), local = TRUE)
source(file.path(repo_root, "monitor", "shared", "R", "monetary_methodology.R"), local = TRUE)
source(file.path(repo_root, "monitor", "shared", "R", "proyecciones.R"), local = TRUE)
source(file.path(repo_root, "monitor", "shared", "R", "series_artifacts.R"), local = TRUE)
source(file.path(repo_root, "monitor", "shared", "R", "caja_artifacts.R"), local = TRUE)
source(file.path(repo_root, "monitor", "pipeline", "steps", "import_proyecciones.R"), local = TRUE)
source(file.path(repo_root, "monitor", "pipeline", "steps", "stage_legacy_app_artifacts.R"), local = TRUE)

run_import_proyecciones(monitor_dir = monitor_dir)
stage_legacy_app_artifacts(repo_root = repo_root, monitor_dir = monitor_dir)
