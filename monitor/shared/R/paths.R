find_monitor_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)

  repeat {
    if (basename(current) == "monitor") {
      return(current)
    }

    candidate <- file.path(current, "monitor")
    if (dir.exists(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }

    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not locate the monitor directory.", call. = FALSE)
    }

    current <- parent
  }
}

monitor_path <- function(..., monitor_dir = find_monitor_root()) {
  file.path(monitor_dir, ...)
}
