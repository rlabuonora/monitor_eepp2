SHELL := /bin/bash
.DEFAULT_GOAL := help

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR := $(ROOT_DIR)/.build
PIPELINE_STAMP := $(BUILD_DIR)/pipeline.stamp
PIPELINE_INPUTS := $(sort $(wildcard $(ROOT_DIR)/monitor/data/raw/*))
PIPELINE_SOURCES := $(shell find $(ROOT_DIR)/monitor/pipeline $(ROOT_DIR)/monitor/shared/R $(ROOT_DIR)/pipeline $(ROOT_DIR)/scripts -type f | sort)
NODE_MODULES_STAMP := $(ROOT_DIR)/node_modules/.e2e-stamp

.PHONY: help setup pipeline app-data verify-data test-pipeline test run-app screenshots screenshots-update e2e e2e-update e2e-clean clean all import run

help:
	@printf '%s\n' \
		'Available targets:' \
		'  help          Print this help.' \
		'  setup         Verify WSL-safe tools and restore renv if present.' \
		'  pipeline      Run the data pipeline end-to-end from repo root.' \
		'  app-data      Guarantee all Shiny-required artifacts exist and verify them.' \
		'  verify-data   Validate required datasets against the data contract.' \
		'  test-pipeline Run the migrated pipeline test suite.' \
		'  test          Run all selected tests.' \
		'  run-app       Start the Shiny app from repo root.' \
		'  screenshots   Capture and compare app screenshots against visual baselines.' \
		'  screenshots-update Refresh screenshot baselines intentionally.' \
		'  e2e           Run headless Playwright UI comparisons against committed baselines.' \
		'  e2e-update    Refresh E2E screenshot baselines intentionally.' \
		'  e2e-clean     Remove generated E2E artifacts only.' \
		'  clean         Remove generated artifacts under data/interim, data/processed, and .build.' \
		'  all           Run setup, app-data, and test.'

setup:
	@case "$$(pwd)" in \
		/mnt/c/*) echo 'Error: run this repo from the WSL filesystem (for example ~/dev/monitor_empresas_publicas), not /mnt/c.' >&2; exit 1 ;; \
	esac
	@command -v Rscript >/dev/null || { echo 'Error: Rscript is required but was not found in PATH.' >&2; exit 1; }
	@command -v R >/dev/null || { echo 'Error: R is required but was not found in PATH.' >&2; exit 1; }
	@mkdir -p "$(BUILD_DIR)"
	@if [ -f "$(ROOT_DIR)/renv.lock" ]; then \
		echo '==> Restoring renv environment'; \
		Rscript --vanilla -e "if (!requireNamespace('renv', quietly = TRUE)) stop('renv.lock is present but package renv is not installed. Install renv in this R environment first.', call. = FALSE); renv::restore(prompt = FALSE)"; \
	else \
		echo '==> No renv detected; skipping restore'; \
	fi
	@Rscript --vanilla -e "cat('R runtime available.\\n')"

pipeline: $(PIPELINE_STAMP)

$(PIPELINE_STAMP): $(PIPELINE_SOURCES) $(PIPELINE_INPUTS)
	@mkdir -p "$(BUILD_DIR)"
	@echo '==> Running pipeline'
	@./scripts/run-pipeline.sh
	@touch "$(PIPELINE_STAMP)"

app-data: pipeline verify-data

verify-data:
	@echo '==> Verifying required datasets'
	@Rscript --vanilla pipeline/verify_required_datasets.R

test-pipeline:
	@echo '==> Running migrated pipeline tests'
	@Rscript --vanilla pipeline/tests/run_tests.R

test:
	@echo '==> Running all selected tests'
	@./scripts/run-tests.sh

run-app:
	@echo '==> Starting Shiny app'
	@./scripts/run-app.sh

screenshots: e2e

screenshots-update: e2e-update

$(NODE_MODULES_STAMP): $(ROOT_DIR)/package.json
	@echo '==> Installing E2E Node dependencies'
	@npm install
	@mkdir -p "$(dir $(NODE_MODULES_STAMP))"
	@touch "$(NODE_MODULES_STAMP)"

e2e: app-data $(NODE_MODULES_STAMP)
	@echo '==> Ensuring Playwright Chromium is installed'
	@npx playwright install chromium
	@echo '==> Running E2E visual regression checks'
	@E2E_RUN_ID="$$(date +%Y%m%dT%H%M%S)" APP_TEST_MODE=1 npx playwright test --config=e2e/playwright.config.js

e2e-update: app-data $(NODE_MODULES_STAMP)
	@echo '==> Ensuring Playwright Chromium is installed'
	@npx playwright install chromium
	@echo '==> Updating E2E baselines (destructive)'
	@E2E_RUN_ID="baseline-update-$$(date +%Y%m%dT%H%M%S)" E2E_UPDATE_BASELINES=1 APP_TEST_MODE=1 npx playwright test --config=e2e/playwright.config.js

e2e-clean:
	@echo '==> Removing E2E artifacts'
	@if [ -d "$(ROOT_DIR)/e2e/artifacts" ]; then find "$(ROOT_DIR)/e2e/artifacts" -mindepth 1 -maxdepth 1 -exec rm -rf {} +; fi

clean:
	@echo '==> Removing generated artifacts'
	@if [ -d "$(ROOT_DIR)/monitor/data/interim" ]; then find "$(ROOT_DIR)/monitor/data/interim" -mindepth 1 -maxdepth 1 -exec rm -rf {} +; fi
	@if [ -d "$(ROOT_DIR)/monitor/data/processed" ]; then find "$(ROOT_DIR)/monitor/data/processed" -mindepth 1 -maxdepth 1 -exec rm -rf {} +; fi
	@if [ -d "$(ROOT_DIR)/e2e/artifacts" ]; then find "$(ROOT_DIR)/e2e/artifacts" -mindepth 1 -maxdepth 1 -exec rm -rf {} +; fi
	@rm -rf "$(BUILD_DIR)"

all: setup app-data test

import: pipeline

run: run-app
