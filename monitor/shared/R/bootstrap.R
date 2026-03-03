resolve_bootstrap_file <- function(fallback = "monitor/shared/R/bootstrap.R") {
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

  stop("Unable to resolve monitor/shared/R/bootstrap.R path.", call. = FALSE)
}

bootstrap_file <- resolve_bootstrap_file()
source(file.path(dirname(bootstrap_file), "paths.R"), local = TRUE)

project_root <- function() {
  dirname(find_monitor_root())
}

project_path <- function(...) {
  file.path(project_root(), ...)
}

load_rda_object <- function(path, object_name = NULL) {
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

fail_test <- function(message_text) {
  stop(message_text, call. = FALSE)
}

assert_true <- function(condition, message_text) {
  if (!isTRUE(condition)) {
    fail_test(message_text)
  }
}

assert_setequal <- function(actual, expected, message_text) {
  if (!setequal(actual, expected)) {
    fail_test(
      sprintf(
        "%s\nActual: %s\nExpected: %s",
        message_text,
        paste(sort(unique(as.character(actual))), collapse = ", "),
        paste(sort(unique(as.character(expected))), collapse = ", ")
      )
    )
  }
}

assert_data_frame_equal <- function(actual, expected, key_cols, tolerance = 0) {
  assert_true(is.data.frame(actual), "Actual value is not a data frame.")
  assert_true(is.data.frame(expected), "Expected value is not a data frame.")
  assert_true(identical(names(actual), names(expected)), "Data frame columns do not match.")

  if (length(key_cols) > 0) {
    actual <- actual[do.call(order, actual[key_cols]), , drop = FALSE]
    expected <- expected[do.call(order, expected[key_cols]), , drop = FALSE]
  }

  rownames(actual) <- NULL
  rownames(expected) <- NULL

  assert_true(nrow(actual) == nrow(expected), "Data frame row counts do not match.")

  for (col_name in names(actual)) {
    lhs <- actual[[col_name]]
    rhs <- expected[[col_name]]

    if (is.numeric(lhs) && is.numeric(rhs)) {
      comparison <- all.equal(lhs, rhs, tolerance = tolerance, check.attributes = FALSE)
      if (!isTRUE(comparison)) {
        fail_test(sprintf("Numeric column '%s' differs: %s", col_name, paste(comparison, collapse = "; ")))
      }
    } else {
      comparison <- identical(as.character(lhs), as.character(rhs))
      if (!comparison) {
        fail_test(sprintf("Column '%s' differs.", col_name))
      }
    }
  }
}
