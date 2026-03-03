# Migration Notes

This repository is being migrated incrementally from a legacy package-like R layout to a plain WSL-friendly project layout.

## Branch Re-Migration Baseline

- Re-migration was re-validated against the files currently present in this workspace.
- The workspace root is not a Git checkout, so branch name and commit hash could not be confirmed here.
- The current branch snapshot already contains the plain-project scaffold (`monitor/`, root `pipeline/`, root `scripts/`, root `Makefile`).
- Baseline checks on this snapshot passed before any new changes:
  - `make all`
  - `./scripts/smoke-test.sh`

## Source Of Truth

- `AGENTS.md` defines the workspace guardrails.
- `legacy/` keeps the old package and old app unchanged for reference.
- `monitor/` is the active plain-project target structure.

## Current Entry Points

- App: `./scripts/dev-run-app.sh`
- Pipeline import: `./scripts/dev-import.sh`
- Smoke test: `./scripts/smoke-test.sh`
- Root make interface: `make all`

The existing Makefiles delegate to these scripts:

- `make pipeline`
- `make app-data`
- `make verify-data`
- `make test`
- `make run-app`
- `make e2e`
- `make e2e-update`
- `make all`

## Inventory Map

Legacy app:

- `legacy/monitor_eepp/app.R`
- `legacy/monitor_eepp/global.R`
- `legacy/monitor_eepp/R/*.R`
- import scripts under `legacy/monitor_eepp/scripts/`

Legacy package-like exports from `legacy/eeppImport/NAMESPACE`:

- `agregar_deflactores`
- `ejecucion_mensual`
- `import_ejecucion`
- `import_firmado`
- `import_firmado_anual`
- `import_firmado_raw`
- `import_proyeccion`
- `refresh_series_data`
- `series_anuales`
- `series_mensuales`

Current plain-project target:

- `monitor/app/` for the Shiny app
- `monitor/pipeline/` for import runners
- `monitor/shared/R/` for shared helpers
- `monitor/data/raw/` for Excel inputs
- `monitor/data/processed/` for generated artifacts

Project-level pipeline contract tooling:

- `pipeline/manifest_required_datasets.json` declares the datasets the app requires
- `pipeline/verify_required_datasets.R` validates those outputs
- `pipeline/discover_app_requirements.R` performs a static scan and writes `pipeline/manifest_candidates.yml`

## Old To New Mapping

- Legacy `monitor_eepp/scripts/importar_firmado.R` proyecciones slice -> `monitor/pipeline/run_import.R`
- Legacy `monitor_eepp/proyecciones.rds` -> `monitor/data/processed/proyecciones.rds`
- Legacy path helpers and deflator logic previously loaded through app/package code -> `monitor/shared/R/*.R`
- Legacy app runtime (`monitor_eepp/app.R`) -> `monitor/app/app.R`

## Compatibility Strategy

- Keep `legacy/` intact during migration.
- Keep function behavior identical for the migrated slice.
- Use thin script wrappers under `scripts/` as the stable WSL entrypoints.
- Avoid any package installation requirement for the new `monitor/` flow.
- No `renv` was added because no `renv` configuration exists in this repo today.

No compatibility shim is required yet beyond these stable entrypoint wrappers, because the current `monitor/` code already runs as a plain project.

## Phase Plan

### Phase 1: Stable WSL Entry Points

- Add `scripts/dev-import.sh`
- Add `scripts/dev-run-app.sh`
- Add `scripts/smoke-test.sh`
- Point existing Makefiles at those scripts

Acceptance checks:

```bash
./scripts/dev-import.sh
```

Expected:

- `Imported dataset: proyecciones`

```bash
./scripts/smoke-test.sh
```

Expected:

- `Smoke test passed`

### Phase 2: Incremental Logic Migration

- Move one legacy dataset at a time from `legacy/` into `monitor/pipeline/` and `monitor/shared/R/`
- Preserve function names and signatures where reused
- Keep app behavior unchanged after each slice

Acceptance check:

```bash
make import
```

Expected:

- processed artifacts are regenerated successfully

### Phase 3: Legacy Decommissioning

- Remove temporary duplication only after all slices are migrated and verified
- Retire legacy entrypoints last

Acceptance check:

- every required dataset builds from `monitor/pipeline/`
- the app runs solely from `monitor/`

## Smoke Tests

Run import only:

```bash
make pipeline
```

Run app in WSL:

```bash
make run-app
```

Expected:

- `Listening on http://0.0.0.0:3838`

Run non-interactive smoke test:

```bash
make test
```

Expected:

- `Smoke test passed`

## Make Workflow

Run the full migration-safe workflow from the repo root:

```bash
make all
```

This performs:

- `make setup`
- `make app-data`
- `make test`

Run only the pipeline:

```bash
make pipeline
```

Run only the selected tests:

```bash
make test
```

Run the headless UI loop:

```bash
make e2e
```

Refresh visual baselines intentionally:

```bash
make e2e-update
```

Artifacts are written under:

- `monitor/data/interim/`
- `monitor/data/processed/`
- `e2e/artifacts/`

Committed visual baselines live under:

- `e2e/baselines/`

The current migrated pipeline writes:

- `monitor/data/processed/proyecciones.rds`

Current environment/config expectations:

- run from the repo root in WSL, not `/mnt/c/...`
- required Excel inputs must exist under `monitor/data/raw/`
- no environment variables are required for the current migrated slice
- if `renv.lock` is added later, `make setup` will attempt `renv::restore()`
- `make e2e` sets `APP_TEST_MODE=1` for deterministic UI rendering

## Requirement Discovery

`pipeline/discover_app_requirements.R` performs a static scan of `monitor/app/` and `monitor/shared/R/`.

How it works:

- detects common read calls such as `readRDS(...)`, `read.csv(...)`, `read_csv(...)`, `arrow::read_parquet(...)`, and `qs::qread(...)`
- resolves simple `monitor_path(...)` assignments before those reads
- writes a candidate contract file to `pipeline/manifest_candidates.yml`

Current limitations:

- it only resolves simple literal path constructions
- it will miss highly dynamic path logic or indirect helper wrappers
- the generated candidate manifest is a draft and must be reviewed before promotion into `pipeline/manifest_required_datasets.json`

## Selected Tests Migrated

Kept and migrated now:

- `test_series_mensuales.R`: final schema check for `series_mensuales`
- `test_series_mensuales.R`: join-safe uniqueness check to prevent silent key duplication
- `test_series_anuales.R`: final schema check for `series_anuales`
- `test_series_anuales.R`: 2024 facet subtotal reconciliation
- `test_series_anuales.R`: AFE 2025 fill subtotal reconciliation
- `test_ejecucion_raw.R`: intermediate schema check for `ejecucion_mensual`
- `test_ejecucion_raw.R`: 2024 header subtotal reconciliation
- `test_ejecucion_raw.R`: 2025 header subtotal reconciliation
- `test_ejecucion_raw.R`: compatibility check for `import_ejecucion()` loading the artifact without package install

Why these were kept:

- they cover schema/columns, join safety, and numeric subtotals
- they can run from the plain project without package `load_all()`
- they work with small fixture artifacts under `pipeline/fixtures/`

Deferred for later:

- UI and Shiny-specific tests
- plot-prep tests in `test_build_plot_base.R`
- parser-heavy low-level cell-assertion tests from `test_ejecucion_raw.R` and `test_import_firmado.R`
- full end-to-end reconstruction tests that depend on package data loading or larger live inputs
