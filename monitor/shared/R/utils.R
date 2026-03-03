ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

assert_file_exists <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Missing required file: %s", path), call. = FALSE)
  }

  invisible(path)
}

read_required_excel <- function(path, ...) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required to run the import pipeline.", call. = FALSE)
  }

  assert_file_exists(path)
  readxl::read_excel(path, ...)
}

parse_legacy_date <- function(x) {
  if (inherits(x, "Date")) {
    return(x)
  }

  if (inherits(x, "POSIXt")) {
    return(as.Date(x))
  }

  x <- trimws(as.character(x))
  as.Date(x, tryFormats = c("%d-%m-%Y", "%d/%m/%Y", "%Y-%m-%d"))
}
