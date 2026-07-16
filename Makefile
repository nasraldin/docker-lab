# docker-lab — macOS + Lima + Debian 13 + Docker Engine
# Run `make help` or `make test`
#
# Design:
#   - Single sources of truth: Brewfile, config/*, lima-docker.yaml, apps/ui/*
#   - Thin scripts under scripts/ (DRY + testable)
#   - Fail-fast recipes; idempotent install steps
#   - Do NOT enable .ONESHELL (breaks @ across multi-line recipes)
#   - `make ui …` uses a conditional branch so words like install/uninstall
#     never pull in lab target prerequisites (Make merges prereqs otherwise)

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

ROOT_DIR      := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SCRIPTS       := $(ROOT_DIR)/scripts
RUN           := /bin/bash
INSTANCE_NAME ?= docker
LIMA_TEMPLATE ?= $(ROOT_DIR)/lima-docker.yaml
CONFIRM       ?=
ARGS          ?=
FIX           ?=
VM            ?=
export ROOT_DIR INSTANCE_NAME LIMA_TEMPLATE CONFIRM
export LIMA_SHELL ?= /bin/bash

.DEFAULT_GOAL := help

# Words that may appear after `make ui …` and must NOT run lab targets.
UI_WORDS := install uninstall up down stop start status open default list ls \
	help rm use ps dockhand arcane \
	deps config lima daemon verify \
	vm-uninstall lab-uninstall uninstall-host \
	purge nuke clean doctor sync-home-template test test-run shell restart \
	cli-install cli-uninstall \
	benchmark upgrade backup restore profile diagnose stats self-test \
	small balanced power

# =============================================================================
ifeq (ui,$(firstword $(MAKECMDGOALS)))
# =============================================================================
# UI dispatch only — stub every other word in MAKECMDGOALS (no prerequisites).

.PHONY: ui $(UI_WORDS)
ui: ## Docker UI: make ui <cmd> [provider]
	@$(RUN) "$(SCRIPTS)/ui.sh" $(filter-out $@,$(MAKECMDGOALS))

$(UI_WORDS):
	@:

# =============================================================================
else
# =============================================================================
# Normal lab targets

##@ Help

.PHONY: help
help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } \
		/^[a-zA-Z0-9_.-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf '%s\n' '' \
		'Workflow:' \
		'  make install                 # ONE-SHOT full lab (deps+config+lima+daemon+verify)' \
		'  make deps|config|lima|daemon # re-run one piece after you change something' \
		'  make ui install [provider]   # optional UI (not in make install)' \
		'  make test                    # project self-test (safe by default)' \
		'  make cli-install             # global ducker CLI' \
		'  make vm-uninstall            # delete Lima VM only' \
		'  make nuke CONFIRM=yes        # full cleanup' \
		''

##@ Install

.PHONY: install
install: deps config lima daemon verify ## Full lab install in one cmd (idempotent; no UI)

.PHONY: deps
deps: ## [override] Homebrew packages (Brewfile)
	@$(RUN) "$(SCRIPTS)/install-deps.sh"

.PHONY: config
config: docker-cli-config shell-env ## [override] Host CLI + shell env (DOCKER_HOST, plugins)

.PHONY: docker-cli-config
docker-cli-config: ## [override] Merge cliPluginsExtraDirs into ~/.docker/config.json
	@$(RUN) "$(SCRIPTS)/install-docker-cli-config.sh"

.PHONY: shell-env
shell-env: ## [override] Install DOCKER_HOST block into ~/.zshrc
	@$(RUN) "$(SCRIPTS)/install-shell-env.sh"

.PHONY: lima
lima: ## [override] Create/start Lima VM from lima-docker.yaml
	@$(RUN) "$(SCRIPTS)/install-lima.sh"

.PHONY: daemon
daemon: ## [override] Apply guest rootless daemon.json + restart Docker
	@$(RUN) "$(SCRIPTS)/install-daemon-config.sh"

##@ Lifecycle

.PHONY: start
start: ## Start the Lima instance
	@limactl start --tty=false $(INSTANCE_NAME)

.PHONY: stop
stop: ## Stop the Lima instance
	@limactl stop $(INSTANCE_NAME)

.PHONY: restart
restart: ## Restart the Lima instance
	@limactl stop -f $(INSTANCE_NAME) || true
	@limactl start --tty=false $(INSTANCE_NAME)

.PHONY: status
status: ## Show Lima + Docker status
	@limactl list || true
	@echo
	@DOCKER_HOST="unix://${HOME}/.lima/$(INSTANCE_NAME)/sock/docker.sock" \
		DOCKER_CONTEXT= \
		docker info --format 'Server={{.ServerVersion}} OS={{.OperatingSystem}} Arch={{.Architecture}}' 2>/dev/null \
		|| echo 'Docker server: unreachable (is the VM running?)'

.PHONY: shell
shell: ## Open a shell in the Lima guest
	@limactl shell $(INSTANCE_NAME)

##@ Verify

.PHONY: verify
verify: ## Run health checks (host tools, VM, Docker, buildx)
	@$(RUN) "$(SCRIPTS)/verify.sh"

.PHONY: doctor
doctor: ## status + verify (FIX=1 make doctor for repairs)
	@$(RUN) "$(SCRIPTS)/doctor.sh" $(if $(filter 1,$(FIX)),--fix,)

.PHONY: diagnose
diagnose: ## Deep host + Lima + Docker diagnostics
	@$(RUN) "$(SCRIPTS)/diagnose.sh"

.PHONY: stats
stats: ## Live Docker stats + Lima summary
	@$(RUN) "$(SCRIPTS)/stats.sh"

.PHONY: test
test: ## Self-test the project (static + safe checks; LIVE=1 for running VM)
	@$(RUN) "$(SCRIPTS)/test.sh"

.PHONY: self-test
self-test: test ## Alias for test

.PHONY: test-run
test-run: ## Smoke-test with alpine + stress-ng (needs running VM)
	@DOCKER_HOST="unix://${HOME}/.lima/$(INSTANCE_NAME)/sock/docker.sock" \
		DOCKER_CONTEXT= \
		docker run --rm alpine uname -a
	@DOCKER_HOST="unix://${HOME}/.lima/$(INSTANCE_NAME)/sock/docker.sock" \
		DOCKER_CONTEXT= \
		docker run --rm ghcr.io/colinianking/stress-ng --cpu 2 --timeout 10s --metrics-brief

.PHONY: benchmark
benchmark: ## Disk I/O, pull, and build timings (needs Running VM)
	@$(RUN) "$(SCRIPTS)/benchmark.sh"

##@ Optional — UI (not part of make install)

.PHONY: ui
ui: ## Docker UI: make ui <install|up|down|open|status|uninstall|default|list> [provider]
	@$(RUN) "$(SCRIPTS)/ui.sh" $(filter-out $@,$(MAKECMDGOALS))

##@ Maintenance

.PHONY: upgrade
upgrade: ## Upgrade brew packages + re-apply config + verify
	@$(RUN) "$(SCRIPTS)/upgrade.sh"

.PHONY: backup
backup: ## Snapshot lab config (VM=1 make backup for Lima archive)
	@$(RUN) "$(SCRIPTS)/backup.sh" $(if $(filter 1,$(VM)),--vm,) $(ARGS)

.PHONY: restore
restore: ## Restore: make restore ARGS='<id>' (VM=1 for VM archive)
	@$(RUN) "$(SCRIPTS)/restore.sh" $(ARGS) $(if $(filter 1,$(VM)),--vm,)

.PHONY: profile
profile: ## VM profiles: make profile ARGS='list|show|small|balanced|power'
	@$(RUN) "$(SCRIPTS)/profile.sh" $(or $(ARGS),list)

.PHONY: sync-home-template
sync-home-template: ## Copy lima-docker.yaml to ~/lima-docker.yaml
	@cp -f "$(LIMA_TEMPLATE)" "$(HOME)/lima-docker.yaml"
	@echo "Updated $(HOME)/lima-docker.yaml"

.PHONY: cli-install
cli-install: ## Install global `ducker` CLI (symlink)
	@$(ROOT_DIR)/ducker cli-install

.PHONY: cli-uninstall
cli-uninstall: ## Remove global `ducker` symlink
	@$(ROOT_DIR)/ducker cli-uninstall

##@ Docs

.PHONY: docs-serve
docs-serve: ## Serve docs locally (http://127.0.0.1:8000)
	@if [[ -x "$(ROOT_DIR)/.venv-docs/bin/mkdocs" ]]; then \
		"$(ROOT_DIR)/.venv-docs/bin/mkdocs" serve; \
	elif command -v mkdocs >/dev/null 2>&1; then \
		mkdocs serve; \
	else \
		echo "Install: python3 -m venv .venv-docs && . .venv-docs/bin/activate && pip install -r requirements-docs.txt"; \
		exit 1; \
	fi

.PHONY: docs-build
docs-build: ## Build static docs site into ./site
	@if [[ -x "$(ROOT_DIR)/.venv-docs/bin/mkdocs" ]]; then \
		"$(ROOT_DIR)/.venv-docs/bin/mkdocs" build --strict; \
	elif command -v mkdocs >/dev/null 2>&1; then \
		mkdocs build --strict; \
	else \
		echo "Install: python3 -m venv .venv-docs && . .venv-docs/bin/activate && pip install -r requirements-docs.txt"; \
		exit 1; \
	fi

.PHONY: docs-diagrams
docs-diagrams: ## Regenerate docs/assets/diagrams/*.svg and *.png
	@command -v rsvg-convert >/dev/null 2>&1 || { echo "Need rsvg-convert (brew install librsvg)"; exit 1; }
	@python3 "$(ROOT_DIR)/scripts/generate-diagrams.py"

##@ Cleanup

.PHONY: vm-uninstall
vm-uninstall: ## Delete Lima instance only (keeps brew + host config)
	@$(RUN) "$(SCRIPTS)/uninstall.sh" instance

.PHONY: lab-uninstall
lab-uninstall: ## Delete instance + remove shell/CLI managed config
	@$(RUN) "$(SCRIPTS)/uninstall.sh" host

.PHONY: uninstall
uninstall: ## Alias for vm-uninstall
	@$(RUN) "$(SCRIPTS)/uninstall.sh" instance

.PHONY: uninstall-host
uninstall-host: ## Alias for lab-uninstall
	@$(RUN) "$(SCRIPTS)/uninstall.sh" host

.PHONY: purge
purge: ## Alias for nuke
	@$(RUN) "$(SCRIPTS)/uninstall.sh" nuke

.PHONY: nuke
nuke: ## FULL cleanup (prompt, or: make nuke CONFIRM=yes)
	@$(RUN) "$(SCRIPTS)/uninstall.sh" nuke

.PHONY: clean
clean: ## Alias: stop VM (non-destructive)
	@limactl stop $(INSTANCE_NAME)

endif
