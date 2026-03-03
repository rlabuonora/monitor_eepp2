resolve_script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) == 0) {
    stop("This script must be run with Rscript or R --file.", call. = FALSE)
  }

  normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)
}

find_repo_root <- function(script_path = resolve_script_path()) {
  normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)
}

trim_ws <- function(x) {
  gsub("^\\s+|\\s+$", "", x)
}

json_escape <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", x)
  x <- gsub("\"", "\\\\\"", x)
  x <- gsub("\n", "\\\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\\\t", x, fixed = TRUE)
  x
}

to_json <- function(value, indent = 0) {
  pad <- paste(rep("  ", indent), collapse = "")
  next_pad <- paste(rep("  ", indent + 1), collapse = "")

  if (is.null(value)) {
    return("null")
  }

  if (is.list(value)) {
    item_names <- names(value)

    if (is.null(item_names)) {
      if (length(value) == 0) {
        return("[]")
      }

      rendered <- vapply(value, to_json, character(1), indent = indent + 1)
      return(
        paste0(
          "[\n",
          paste0(next_pad, rendered, collapse = ",\n"),
          "\n",
          pad,
          "]"
        )
      )
    }

    if (length(value) == 0) {
      return("{}")
    }

    rendered <- vapply(seq_along(value), function(i) {
      key <- json_escape(item_names[[i]])
      val <- to_json(value[[i]], indent = indent + 1)
      sprintf("%s\"%s\": %s", next_pad, key, val)
    }, character(1))

    return(
      paste0(
        "{\n",
        paste(rendered, collapse = ",\n"),
        "\n",
        pad,
        "}"
      )
    )
  }

  if (is.character(value)) {
    if (length(value) == 0) {
      return("[]")
    }

    if (length(value) == 1) {
      return(sprintf("\"%s\"", json_escape(value)))
    }

    rendered <- sprintf("%s\"%s\"", next_pad, json_escape(value))
    return(
      paste0(
        "[\n",
        paste(rendered, collapse = ",\n"),
        "\n",
        pad,
        "]"
      )
    )
  }

  if (is.logical(value)) {
    if (length(value) == 0) {
      return("[]")
    }

    if (length(value) == 1) {
      return(if (isTRUE(value)) "true" else "false")
    }

    rendered <- ifelse(value, "true", "false")
    rendered <- paste0(next_pad, rendered)
    return(
      paste0(
        "[\n",
        paste(rendered, collapse = ",\n"),
        "\n",
        pad,
        "]"
      )
    )
  }

  if (is.numeric(value)) {
    if (length(value) == 0) {
      return("[]")
    }

    if (length(value) == 1) {
      return(format(value, scientific = FALSE, trim = TRUE))
    }

    rendered <- paste0(next_pad, format(value, scientific = FALSE, trim = TRUE))
    return(
      paste0(
        "[\n",
        paste(rendered, collapse = ",\n"),
        "\n",
        pad,
        "]"
      )
    )
  }

  stop("Unsupported JSON value type.", call. = FALSE)
}

json_parse_text <- function(text) {
  pos <- 1L
  len <- nchar(text)

  skip_ws <- function() {
    while (pos <= len) {
      ch <- substr(text, pos, pos)
      if (!grepl("\\s", ch)) {
        break
      }
      pos <<- pos + 1L
    }
  }

  parse_string <- function() {
    if (substr(text, pos, pos) != "\"") {
      stop("Expected string.", call. = FALSE)
    }

    pos <<- pos + 1L
    out <- character()

    while (pos <= len) {
      ch <- substr(text, pos, pos)

      if (ch == "\"") {
        pos <<- pos + 1L
        return(paste(out, collapse = ""))
      }

      if (ch == "\\") {
        pos <<- pos + 1L
        esc <- substr(text, pos, pos)
        mapped <- switch(
          esc,
          "\"" = "\"",
          "\\" = "\\",
          "/" = "/",
          "b" = "\b",
          "f" = "\f",
          "n" = "\n",
          "r" = "\r",
          "t" = "\t",
          stop("Unsupported JSON escape sequence.", call. = FALSE)
        )
        out <- c(out, mapped)
        pos <<- pos + 1L
        next
      }

      out <- c(out, ch)
      pos <<- pos + 1L
    }

    stop("Unterminated JSON string.", call. = FALSE)
  }

  parse_number <- function() {
    remaining <- substr(text, pos, len)
    match <- regexpr("^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?", remaining)

    if (match[[1]] != 1) {
      stop("Invalid JSON number.", call. = FALSE)
    }

    token <- regmatches(remaining, match)
    pos <<- pos + nchar(token)
    as.numeric(token)
  }

  parse_array <- function() {
    if (substr(text, pos, pos) != "[") {
      stop("Expected array.", call. = FALSE)
    }

    pos <<- pos + 1L
    skip_ws()

    items <- list()
    if (substr(text, pos, pos) == "]") {
      pos <<- pos + 1L
      return(items)
    }

    repeat {
      items[[length(items) + 1L]] <- parse_value()
      skip_ws()

      ch <- substr(text, pos, pos)
      if (ch == "]") {
        pos <<- pos + 1L
        return(items)
      }

      if (ch != ",") {
        stop("Expected ',' or ']'.", call. = FALSE)
      }

      pos <<- pos + 1L
      skip_ws()
    }
  }

  parse_object <- function() {
    if (substr(text, pos, pos) != "{") {
      stop("Expected object.", call. = FALSE)
    }

    pos <<- pos + 1L
    skip_ws()

    values <- list()
    if (substr(text, pos, pos) == "}") {
      pos <<- pos + 1L
      return(values)
    }

    repeat {
      key <- parse_string()
      skip_ws()

      if (substr(text, pos, pos) != ":") {
        stop("Expected ':'.", call. = FALSE)
      }

      pos <<- pos + 1L
      skip_ws()
      values[[key]] <- parse_value()
      skip_ws()

      ch <- substr(text, pos, pos)
      if (ch == "}") {
        pos <<- pos + 1L
        return(values)
      }

      if (ch != ",") {
        stop("Expected ',' or '}'.", call. = FALSE)
      }

      pos <<- pos + 1L
      skip_ws()
    }
  }

  parse_value <- function() {
    skip_ws()
    ch <- substr(text, pos, pos)

    if (ch == "{") {
      return(parse_object())
    }

    if (ch == "[") {
      return(parse_array())
    }

    if (ch == "\"") {
      return(parse_string())
    }

    if (grepl("[-0-9]", ch)) {
      return(parse_number())
    }

    remaining <- substr(text, pos, len)

    if (startsWith(remaining, "true")) {
      pos <<- pos + 4L
      return(TRUE)
    }

    if (startsWith(remaining, "false")) {
      pos <<- pos + 5L
      return(FALSE)
    }

    if (startsWith(remaining, "null")) {
      pos <<- pos + 4L
      return(NULL)
    }

    stop("Unexpected JSON token.", call. = FALSE)
  }

  value <- parse_value()
  skip_ws()

  if (pos <= len) {
    stop("Unexpected trailing JSON content.", call. = FALSE)
  }

  value
}

list_to_character <- function(x) {
  if (is.null(x)) {
    return(character())
  }

  if (is.list(x)) {
    if (length(x) == 0) {
      return(character())
    }
    return(vapply(x, as.character, character(1)))
  }

  as.character(x)
}

normalize_manifest_entry <- function(entry) {
  entry$minimum_schema <- entry$minimum_schema %||% list()
  entry$freshness <- entry$freshness %||% list()
  entry$validation_rules <- entry$validation_rules %||% list()

  entry$minimum_schema$required_columns <- list_to_character(entry$minimum_schema$required_columns)
  entry$minimum_schema$optional_columns <- list_to_character(entry$minimum_schema$optional_columns)
  entry$minimum_schema$key_columns <- list_to_character(entry$minimum_schema$key_columns)

  entry
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

read_required_manifest <- function(path) {
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  parsed <- json_parse_text(text)

  if (!is.list(parsed) || is.null(parsed$required_datasets)) {
    stop("Manifest must contain a top-level 'required_datasets' array.", call. = FALSE)
  }

  lapply(parsed$required_datasets, normalize_manifest_entry)
}

write_required_manifest <- function(entries, path) {
  payload <- list(required_datasets = entries)
  writeLines(to_json(payload), path, useBytes = TRUE)
}

yaml_escape <- function(x) {
  gsub("'", "''", x, fixed = TRUE)
}

write_candidate_manifest <- function(entries, path) {
  lines <- c("required_datasets:")

  for (entry in entries) {
    lines <- c(lines, sprintf("  - id: %s", entry$id))
    lines <- c(lines, sprintf("    description: '%s'", yaml_escape(entry$description)))
    lines <- c(lines, sprintf("    produced_by: %s", entry$produced_by))
    lines <- c(lines, sprintf("    output_path: %s", entry$output_path))
    lines <- c(lines, sprintf("    format: %s", entry$format))
    lines <- c(lines, "    minimum_schema:")
    lines <- c(lines, "      required_columns: []")
    lines <- c(lines, "      optional_columns: []")
    lines <- c(lines, "      key_columns: []")
    lines <- c(lines, "    freshness: {}")
    lines <- c(lines, "    validation_rules:")
    lines <- c(lines, "      row_count_min: 1")
    lines <- c(lines, "      unique_key: false")
  }

  writeLines(lines, path, useBytes = TRUE)
}

strip_extension <- function(path) {
  sub("\\.[^.]+$", "", basename(path))
}
