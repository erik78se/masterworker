# VARIABLES
export PATH := /snap/bin:$(PATH)
export CHARM_NAME_MASTER := master
export CHARM_NAME_WORKER := worker
export CHARM_BUILD_DIR := ./builds

# TARGETS

lint: ## Run linter
	echo "No linting"

build-master: clean lint ## Build charm
	mkdir -p $(CHARM_BUILD_DIR)/$(CHARM_NAME_MASTER)
	cp -r master/* $(CHARM_BUILD_DIR)/$(CHARM_NAME_MASTER)
	charm proof $(CHARM_BUILD_DIR)/$(CHARM_NAME_MASTER)

build-worker: clean lint ## Build charm
	mkdir -p $(CHARM_BUILD_DIR)/$(CHARM_NAME_WORKER)
	cp -r worker/* $(CHARM_BUILD_DIR)/$(CHARM_NAME_WORKER)
	charm proof $(CHARM_BUILD_DIR)/$(CHARM_NAME_WORKER)

build: build-master build-worker

clean: ## build dirs
	find . -name '*~' | xargs rm 
	rm -rf $(CHARM_BUILD_DIR)


# Display target comments in 'make help'
help:
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# SETTINGS
# Use one shell for all commands in a target recipe
.ONESHELL:
# Set default goal
.DEFAULT_GOAL := help
# Use bash shell in Make instead of sh
SHELL := /bin/bash
