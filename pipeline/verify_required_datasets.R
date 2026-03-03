args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
if (length(file_arg) == 0) {
  stop("This script must be run with Rscript or R --file.", call. = FALSE)
}

script_path <- normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)
source(file.path(dirname(script_path), "common.R"), local = TRUE)

repo_root <- find_repo_root()
manifest_path <- file.path(repo_root, "pipeline", "manifest_required_datasets.json")
entries <- read_required_manifest(manifest_path)

read_dataset <- function(path, format) {
  switch(
    format,
    rds = readRDS(path),
    csv = utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    stop(sprintf("Unsupported dataset format '%s'.", format), call. = FALSE)
  )
}

suggest_regeneration_command <- function(entry) {
  if (startsWith(entry$produced_by %||% "", "monitor/pipeline/")) {
    return("./scripts/dev-import.sh")
  }

  "Rscript monitor/pipeline/run_import.R"
}

new_issue <- function(type, entry, detail) {
  list(
    type = type,
    id = entry$id,
    output_path = entry$output_path,
    produced_by = entry$produced_by,
    detail = detail,
    regenerate = suggest_regeneration_command(entry)
  )
}

issues <- list()
passes <- list()

for (entry in entries) {
  dataset_path <- file.path(repo_root, entry$output_path)
  entry_issues <- list()

  if (!file.exists(dataset_path)) {
    entry_issues[[length(entry_issues) + 1L]] <- new_issue(
      "missing",
      entry,
      "File does not exist."
    )
  } else {
    dataset <- tryCatch(
      read_dataset(dataset_path, entry$format),
      error = function(err) err
    )

    if (inherits(dataset, "error")) {
      entry_issues[[length(entry_issues) + 1L]] <- new_issue(
        "unreadable",
        entry,
        conditionMessage(dataset)
      )
    } else {
      required_columns <- entry$minimum_schema$required_columns
      key_columns <- entry$minimum_schema$key_columns

      if (length(required_columns) > 0 || length(key_columns) > 0 || !is.null(entry$validation_rules$row_count_min)) {
        if (!is.data.frame(dataset)) {
          entry_issues[[length(entry_issues) + 1L]] <- new_issue(
            "schema",
            entry,
            "Dataset is not tabular; expected a data.frame-like object."
          )
        } else {
          missing_columns <- setdiff(required_columns, names(dataset))
          if (length(missing_columns) > 0) {
            entry_issues[[length(entry_issues) + 1L]] <- new_issue(
              "schema",
              entry,
              sprintf("Missing required columns: %s", paste(missing_columns, collapse = ", "))
            )
          }

          row_count_min <- entry$validation_rules$row_count_min %||% NULL
          if (!is.null(row_count_min) && nrow(dataset) < row_count_min) {
            entry_issues[[length(entry_issues) + 1L]] <- new_issue(
              "row_count",
              entry,
              sprintf("Row count %d is below minimum %d.", nrow(dataset), row_count_min)
            )
          }

          unique_key <- isTRUE(entry$validation_rules$unique_key)
          if (unique_key) {
            if (length(key_columns) == 0) {
              entry_issues[[length(entry_issues) + 1L]] <- new_issue(
                "schema",
                entry,
                "unique_key is true but key_columns is empty."
              )
            } else if (anyDuplicated(dataset[key_columns]) > 0) {
              entry_issues[[length(entry_issues) + 1L]] <- new_issue(
                "schema",
                entry,
                sprintf("Duplicate rows found for key columns: %s", paste(key_columns, collapse = ", "))
              )
            }
          }
        }
      }

      max_age_hours <- entry$freshness$max_age_hours %||% NULL
      if (!is.null(max_age_hours)) {
        file_age <- as.numeric(difftime(Sys.time(), file.info(dataset_path)$mtime, units = "hours"))
        if (is.na(file_age) || file_age > max_age_hours) {
          entry_issues[[length(entry_issues) + 1L]] <- new_issue(
            "stale",
            entry,
            sprintf("File age %.2f hours exceeds max_age_hours %s.", file_age, max_age_hours)
          )
        }
      }
    }
  }

  if (length(entry_issues) == 0) {
    passes[[length(passes) + 1L]] <- entry
  } else {
    issues <- c(issues, entry_issues)
  }
}

cat(sprintf("Checked %d required dataset(s) from %s\n", length(entries), manifest_path))

if (length(issues) == 0) {
  cat(sprintf("PASS: %d/%d dataset(s) valid.\n", length(passes), length(entries)))
  quit(save = "no", status = 0)
}

failed_ids <- unique(vapply(issues, function(issue) issue$id, character(1)))
cat(sprintf("FAIL: %d/%d dataset(s) invalid.\n", length(failed_ids), length(entries)))

print_issue_section <- function(title, type) {
  matching <- Filter(function(issue) identical(issue$type, type), issues)
  if (length(matching) == 0) {
    return(invisible(NULL))
  }

  cat(sprintf("\n%s:\n", title))
  for (issue in matching) {
    cat(sprintf("- dataset id: %s\n", issue$id))
    cat(sprintf("  expected output_path: %s\n", issue$output_path))
    cat(sprintf("  produced_by: %s\n", issue$produced_by))
    cat(sprintf("  problem: %s\n", issue$detail))
    cat(sprintf("  suggested command: %s\n", issue$regenerate))
  }
}

print_issue_section("Missing Datasets", "missing")
print_issue_section("Unreadable Datasets", "unreadable")
print_issue_section("Schema Mismatches", "schema")
print_issue_section("Row Count Failures", "row_count")
print_issue_section("Stale Outputs", "stale")

quit(save = "no", status = 1)
