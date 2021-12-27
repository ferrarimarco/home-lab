.PHONY: all
all: size-components-esp-idf-project compress-binary-image ## Run all targets.

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

ESP32_RFC2217_SERVER_PORT ?= 3000

.PHONY: fullclean-esp-idf-project
fullclean-esp-idf-project: ## Clean the ESP-IDF project.
	rm -f sdkconfig \
	&& docker run --rm -i $(DOCKER_FLAGS) \
		-v "$(CURDIR)":/workspace \
		-w="/workspace" \
		"$(ESP_IDF_CONTAINER_IMAGE_TAG)" \
		idf.py \
		fullclean

.PHONY: erase-flash-esp-idf-project
erase-flash-esp-idf-project: ## Erase the flash memory.
	docker run --rm -i $(DOCKER_FLAGS) \
		--network host \
		-v "$(CURDIR)":/workspace \
		-w="/workspace" \
		"$(ESP_IDF_CONTAINER_IMAGE_TAG)" \
		idf.py \
		-p rfc2217://localhost:$(ESP32_RFC2217_SERVER_PORT) \
		erase_flash

.PHONY: flash-monitor-esp-idf-project
flash-monitor-esp-idf-project: ## Flash the firmware and launch the ESP-IDF project monitor.
	docker run --rm -i $(DOCKER_FLAGS) \
		--network host \
		-v "$(CURDIR)":/workspace \
		-w="/workspace" \
		"$(ESP_IDF_CONTAINER_IMAGE_TAG)" \
		idf.py \
		-p rfc2217://localhost:$(ESP32_RFC2217_SERVER_PORT) \
		flash \
		monitor

.PHONY: menuconfig-esp-idf-project
menuconfig-esp-idf-project: ## Launch the ESP-IDF project menuconfig.
	docker run --rm -i $(DOCKER_FLAGS) \
		--network host \
		-v "$(CURDIR)":/workspace \
		-w="/workspace" \
		"$(ESP_IDF_CONTAINER_IMAGE_TAG)" \
		idf.py \
		menuconfig

.PHONY: monitor-esp-idf-project
monitor-esp-idf-project: ## Launch the ESP-IDF project monitor.
	docker run --rm -i $(DOCKER_FLAGS) \
		--network host \
		-v "$(CURDIR)":/workspace \
		-w="/workspace" \
		"$(ESP_IDF_CONTAINER_IMAGE_TAG)" \
		idf.py \
		-p rfc2217://localhost:$(ESP32_RFC2217_SERVER_PORT) \
		monitor

.PHONY: size-components-esp-idf-project
size-components-esp-idf-project: ## Launch the ESP-IDF project size-components.
	docker run --rm -i $(DOCKER_FLAGS) \
		-v "$(CURDIR)":/workspace \
		-w="/workspace" \
		"$(ESP_IDF_CONTAINER_IMAGE_TAG)" \
		idf.py \
		size-components

BINARY_IMAGE_COMPRESSION_IMAGE_TAG ?= ubuntu:20.04

.PHONY: compress-binary-image
compress-binary-image: build-esp-idf-project
	docker run --rm -i $(DOCKER_FLAGS) \
		-v "$(CURDIR)":/workspace \
		-w="/workspace" \
		"$(BINARY_IMAGE_COMPRESSION_IMAGE_TAG)" \
		bash -c "xz -9 --compress --force --threads=0 --verbose provisioning/esp32/smart_desk/build/smart-desk.bin"

RFC2217_EXEC_PATH ?= .env/rfc2217_server.py

.PHONY: setup-rfc2217-server
setup-rfc2217-server: ## Set up a RFC 2217 server to interact with the serial port over the network. Requires Python 3
	python3 -m venv ./.env; \
	. .env/bin/activate; \
	pip3 install pyserial; \
	[ -e "$(RFC2217_EXEC_PATH)" ] || curl https://raw.githubusercontent.com/pyserial/pyserial/v3.5/examples/rfc2217_server.py --output "$(RFC2217_EXEC_PATH)"

ESP32_SERIAL_PORT ?= /dev/cu.SLAB_USBtoUART

.PHONY: start-rfc2217-server
start-rfc2217-server: setup-rfc2217-server ## Start a RFC 2217 server to interact with the serial port over the network.
	. .env/bin/activate; \
	python3 "$(RFC2217_EXEC_PATH)" -p $(ESP32_RFC2217_SERVER_PORT) -v "$(ESP32_SERIAL_PORT)"
