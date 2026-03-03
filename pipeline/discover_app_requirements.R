args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
if (length(file_arg) == 0) {
  stop("This script must be run with Rscript or R --file.", call. = FALSE)
}

script_path <- normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)
source(file.path(dirname(script_path), "common.R"), local = TRUE)

repo_root <- find_repo_root()
scan_dirs <- c(
  file.path(repo_root, "monitor", "app"),
  file.path(repo_root, "monitor", "shared", "R")
)
manifest_entries <- if (file.exists(file.path(repo_root, "pipeline", "manifest_required_datasets.json"))) {
  read_required_manifest(file.path(repo_root, "pipeline", "manifest_required_datasets.json"))
} else {
  list()
}
manifest_index <- manifest_entries
names(manifest_index) <- vapply(manifest_entries, function(entry) entry$id, character(1))

read_patterns <- list(
  readRDS = "rds",
  "read.csv" = "csv",
  read_csv = "csv",
  "arrow::read_parquet" = "parquet",
  read_parquet = "parquet",
  "qs::qread" = "qs"
)

extract_quoted_values <- function(text) {
  match <- gregexpr("\"[^\"]+\"|'[^']+'", text, perl = TRUE)
  if (match[[1]][1] == -1) {
    return(character())
  }

  values <- regmatches(text, match)[[1]]
  substring(values, 2, nchar(values) - 1)
}

extract_monitor_path_bindings <- function(lines) {
  bindings <- list()

  for (line in lines) {
    if (!grepl("<-\\s*monitor_path\\(", line)) {
      next
    }

    var_name <- sub("^\\s*([A-Za-z][A-Za-z0-9._]*)\\s*<-.*$", "\\1", line)
    args_text <- sub("^.*monitor_path\\((.*)\\).*$", "\\1", line)
    pieces <- extract_quoted_values(args_text)

    if (length(pieces) > 0) {
      bindings[[var_name]] <- do.call(file.path, as.list(c("monitor", pieces)))
    }
  }

  bindings
}

detect_reads <- function(lines, bindings) {
  found <- list()

  for (line in lines) {
    if (grepl("read_required_dataset(", line, fixed = TRUE)) {
      ids <- extract_quoted_values(line)
      if (length(ids) > 0 && !is.null(manifest_index[[ids[[1]]]])) {
        entry <- manifest_index[[ids[[1]]]]
        found[[length(found) + 1L]] <- list(
          output_path = entry$output_path,
          format = entry$format
        )
      }
    }

    for (fn in names(read_patterns)) {
      pattern <- sprintf("(^|[^A-Za-z0-9_:])%s\\(([^,\\)]+)", gsub("\\.", "\\\\.", fn))

      if (!grepl(pattern, line, perl = TRUE)) {
        next
      }

      arg <- sub(sprintf("^.*%s\\(([^,\\)]+).*$", gsub("\\.", "\\\\.", fn)), "\\1", line, perl = TRUE)
      arg <- trim_ws(arg)
      path <- NULL

      if (grepl("^[\"'].*[\"']$", arg)) {
        path <- substring(arg, 2, nchar(arg) - 1)
      } else if (!is.null(bindings[[arg]])) {
        path <- bindings[[arg]]
      }

      if (!is.null(path)) {
        found[[length(found) + 1L]] <- list(
          output_path = path,
          format = read_patterns[[fn]]
        )
      }
    }
  }

  found
}

files <- sort(unlist(lapply(scan_dirs, function(path) {
  if (!dir.exists(path)) {
    return(character())
  }

  list.files(path, pattern = "[.]R$", full.names = TRUE, recursive = TRUE)
})))

candidates <- list()
seen <- character()

for (file in files) {
  lines <- readLines(file, warn = FALSE)
  bindings <- extract_monitor_path_bindings(lines)
  reads <- detect_reads(lines, bindings)

  for (read in reads) {
    key <- paste(read$output_path, read$format, sep = "::")
    if (key %in% seen) {
      next
    }

    seen <- c(seen, key)
    candidates[[length(candidates) + 1L]] <- list(
      id = strip_extension(read$output_path),
      description = sprintf(
        "Auto-discovered from %s via static scan. Review and fill in schema details.",
        sub(paste0("^", repo_root, "/?"), "", file)
      ),
      produced_by = "TODO",
      output_path = read$output_path,
      format = read$format
    )
  }
}

candidate_path <- file.path(repo_root, "pipeline", "manifest_candidates.yml")
write_candidate_manifest(candidates, candidate_path)

cat(sprintf("Discovered %d candidate dataset(s).\n", length(candidates)))
cat(sprintf("Wrote: %s\n", candidate_path))
