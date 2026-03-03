THIS_MAKEFILE := $(lastword $(MAKEFILE_LIST))
DEV_DIR := $(dir $(abspath $(THIS_MAKEFILE)))
ROOT_DIR := $(abspath $(DEV_DIR)/../..)

.PHONY: import run

import:
	cd "$(ROOT_DIR)" && $(MAKE) pipeline

run:
	cd "$(ROOT_DIR)" && $(MAKE) run-app
