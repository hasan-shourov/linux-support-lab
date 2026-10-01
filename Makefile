SHELL := /bin/bash
SUDO := $(if $(filter 0,$(shell id -u)),,sudo)
SCRIPTS := $(shell find . -name "*.sh" -not -path "./.git/*" | sort)

.DEFAULT_GOAL := help
.PHONY: help setup lint test list reset

help:
	@echo "Linux Troubleshooting Lab"
	@echo ""
	@echo "  make setup   Install the tools the lab needs (needs root)"
	@echo "  make lint    Run bash -n and shellcheck on every script"
	@echo "  make test    Run the smoke test (needs root and systemd)"
	@echo "  make list    Show the 10 scenarios"
	@echo "  make reset   Fix the active scenario and clean up lab state"

setup:
	$(SUDO) ./setup.sh

lint:
	@for f in $(SCRIPTS); do bash -n "$$f" || exit 1; done
	@command -v shellcheck >/dev/null || { echo "shellcheck is not installed. Run: make setup"; exit 1; }
	@shellcheck -x $(SCRIPTS)
	@echo "Lint passed: $(words $(SCRIPTS)) scripts checked."

test:
	$(SUDO) ./tests/smoke_test.sh

list:
	./lab.sh list

reset:
	$(SUDO) ./lab.sh reset
