source("monitor/shared/R/bootstrap.R", local = FALSE)

test_results <- list()

run_test <- function(name, code) {
  outcome <- tryCatch(
    {
      force(code)
      list(name = name, ok = TRUE, message = NULL)
    },
    error = function(err) {
      list(name = name, ok = FALSE, message = conditionMessage(err))
    }
  )

  test_results[[length(test_results) + 1L]] <<- outcome

  if (isTRUE(outcome$ok)) {
    cat(sprintf("PASS %s\n", outcome$name))
  } else {
    cat(sprintf("FAIL %s\n", outcome$name))
    cat(sprintf("  %s\n", outcome$message))
  }
}

test_files <- sort(list.files("pipeline/tests/cases", pattern = "[.]R$", full.names = TRUE))

for (test_file in test_files) {
  source(test_file, local = FALSE)
}

total <- length(test_results)
failed <- vapply(test_results, function(item) !isTRUE(item$ok), logical(1))
failed_count <- sum(failed)
passed_count <- total - failed_count

cat(sprintf("Summary: %d passed, %d failed, %d total\n", passed_count, failed_count, total))

if (failed_count > 0) {
  quit(save = "no", status = 1)
}
