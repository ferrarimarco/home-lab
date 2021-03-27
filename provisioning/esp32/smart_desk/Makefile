.PHONY: all
all: build-esp-idf-project tag-esp-idf-project-executable ## Run all targets.

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

ESP_IDF_CONTAINER_IMAGE_TAG ?= espressif/idf:release-v4.3

.PHONY: build-esp-idf-project
build-esp-idf-project: ## Build the ESP-IDF project.
	docker run --rm -i $(DOCKER_FLAGS) \
		-v "$(CURDIR)":/workspace \
		-w="/workspace" \
		"$(ESP_IDF_CONTAINER_IMAGE_TAG)" \
		idf.py \
		build

.PHONY: help
help: ## Show help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

ESP_IDF_SERIAL_PORT ?= /dev/cu.SLAB_USBtoUART

.PHONY: monitor-esp-idf-project
monitor-esp-idf-project: ## Launch the ESP-IDF project monitor.
	docker run --rm -i $(DOCKER_FLAGS) \
		--device "$(ESP_IDF_SERIAL_PORT)" \
		-v "$(CURDIR)":/workspace \
		-w="/workspace" \
		"$(ESP_IDF_CONTAINER_IMAGE_TAG)" \
		idf.py \
		-p "$(ESP_IDF_SERIAL_PORT)" \
		monitor

PROJECT_EXECUTABLE_TAG ?= latest

.PHONY: tag-esp-idf-project-executable
tag-esp-idf-project-executable: ## Add a build-specific tag to the esp-idf project executable
	mv "build/smart-desk.bin" "build/smart-desk-$(PROJECT_EXECUTABLE_TAG).bin"
