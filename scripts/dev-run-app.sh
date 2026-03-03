#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

R -q -e "shiny::runApp('monitor/app', host='0.0.0.0', port=3838)"
