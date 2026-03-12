## Workspace Layout

- `legacy/` contains the old package-based import code and the old Shiny app.
- `monitor/` contains the new pipeline-based architecture.

## Rules

- Do not read Excel files from `monitor/app`.
- The pipeline writes outputs to `monitor/data/processed/`.
- Shared reusable functions belong in `monitor/shared/R/`.
- Use relative paths only; do not hardcode absolute paths.
- Run the pipeline with `Rscript monitor/pipeline/run_import.R`.
- Run the app with `R -q -e "shiny::runApp('monitor/app')"`.

## Commands

- Build all app datasets from the Excel files in `monitor/data/raw/`: `make app-data`
- Run the pipeline test suite: `make test-pipeline`
- Run the Shiny app: `make run-app`
- Take app screenshots and compare against visual baselines: `make screenshots`
- Update screenshot baselines intentionally: `make screenshots-update`

## Roles

- Orchestrator: manage structure, sequencing, and migration boundaries.
- Pipeline: implement import and processing steps under `monitor/pipeline/`.
- App: implement the Shiny interface under `monitor/app/`.
- Shared: maintain common utilities under `monitor/shared/R/`.
