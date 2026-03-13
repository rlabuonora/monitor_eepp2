resolve_app_bootstrap_file <- function(fallback = "monitor/app/bootstrap.R") {
  frames <- rev(sys.frames())

  for (env in frames) {
    ofile <- get0("ofile", envir = env, ifnotfound = NULL, inherits = FALSE)
    if (is.character(ofile) && length(ofile) == 1 && nzchar(ofile)) {
      return(normalizePath(ofile, winslash = "/", mustWork = TRUE))
    }
  }

  candidate <- normalizePath(fallback, winslash = "/", mustWork = FALSE)
  if (file.exists(candidate)) {
    return(candidate)
  }

  stop("Unable to resolve monitor/app/bootstrap.R path.", call. = FALSE)
}

app_bootstrap_file <- resolve_app_bootstrap_file()
app_dir <- dirname(app_bootstrap_file)

source(file.path(app_dir, "..", "shared", "R", "bootstrap.R"), local = TRUE)
source(file.path(app_dir, "..", "shared", "R", "monetary_methodology.R"), local = TRUE)
source(project_path("pipeline", "common.R"), local = TRUE)
source(file.path(app_dir, "R", "data_access.R"), local = TRUE)

app_config <- list(
  run_app_data_command = "make app-data",
  manifest_path = project_path("pipeline", "manifest_required_datasets.json")
)

app_source <- function(path, envir = parent.frame()) {
  source(file.path(app_dir, path), local = envir)
}
