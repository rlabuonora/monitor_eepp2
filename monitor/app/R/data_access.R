app_required_dataset_ids <- function() {
  c(
    "series_anuales",
    "series_mensuales",
    "caja_mensual",
    "serie_ipc_anual_24",
    "serie_pib_anual",
    "dolar_promedio_anual"
  )
}

list_required_datasets <- function() {
  manifest_path <- project_path("pipeline", "manifest_required_datasets.json")
  read_required_manifest(manifest_path)
}

app_data_paths <- function() {
  entries <- list_required_datasets()
  values <- lapply(entries, function(entry) {
    list(
      id = entry$id,
      path = project_path(entry$output_path),
      format = entry$format,
      produced_by = entry$produced_by
    )
  })
  names(values) <- vapply(entries, function(entry) entry$id, character(1))
  values
}

read_declared_format <- function(path, format) {
  switch(
    format,
    rds = readRDS(path),
    csv = utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    stop(sprintf("Unsupported dataset format '%s'.", format), call. = FALSE)
  )
}

find_required_dataset_entry <- function(id) {
  entries <- list_required_datasets()
  match <- Filter(function(entry) identical(entry$id, id), entries)

  if (length(match) != 1) {
    stop(sprintf("Dataset id '%s' is not declared in the required data manifest.", id), call. = FALSE)
  }

  match[[1]]
}

validate_required_dataset <- function(data, entry) {
  required_columns <- entry$minimum_schema$required_columns %||% character()

  if (length(required_columns) == 0) {
    return(invisible(data))
  }

  if (!is.data.frame(data)) {
    stop(sprintf("Dataset '%s' is not tabular; expected a data.frame-like object.", entry$id), call. = FALSE)
  }

  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0) {
    stop(
      sprintf(
        "Dataset '%s' is missing required columns: %s",
        entry$id,
        paste(missing_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  invisible(data)
}

read_required_dataset <- function(id) {
  entry <- find_required_dataset_entry(id)
  dataset_path <- project_path(entry$output_path)

  if (!file.exists(dataset_path)) {
    stop(
      sprintf(
        "Required dataset '%s' is missing at %s. Run %s to generate it (pipeline step: %s).",
        entry$id,
        dataset_path,
        "make app-data",
        entry$produced_by
      ),
      call. = FALSE
    )
  }

  data <- tryCatch(
    read_declared_format(dataset_path, entry$format),
    error = function(err) {
      stop(
        sprintf(
          "Failed to read required dataset '%s' at %s: %s",
          entry$id,
          dataset_path,
          conditionMessage(err)
        ),
        call. = FALSE
      )
    }
  )

  validate_required_dataset(data, entry)
  data
}
