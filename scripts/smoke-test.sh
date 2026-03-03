#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./scripts/dev-import.sh

Rscript --vanilla pipeline/verify_required_datasets.R
./scripts/run-pipeline-tests.sh

Rscript --vanilla -e "if (requireNamespace('shiny', quietly = TRUE)) { app <- shiny::shinyAppDir('monitor/app'); stopifnot(inherits(app, 'shiny.appobj')); cat('Smoke test passed\\n') } else { parse(file = 'monitor/app/app.R'); cat('Smoke test passed (app entrypoint parses; shiny not installed in this R library)\\n') }"
