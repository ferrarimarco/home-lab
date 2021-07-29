.PHONY: all
all: build-os-image-raspberry-pi-4-ubuntu ## Build OS images.

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

.PHONY: build-os-image-raspberry-pi-4-ubuntu
build-os-image-raspberry-pi-4-ubuntu: ## Build the Ubuntu OS image for the Raspberry Pi 4.
	docker run --rm -i $(DOCKER_FLAGS) \
		--privileged \
		-v "$(CURDIR)":/workspace \
		-w="/workspace" \
		arm-image-builder \
		--entrypoint /workspace/build.sh \
		--options "--build-config /workspace/config/build.conf --cloud-init-meta-data /workspace/config/cloud-init/meta-data.yaml --cloud-init-network-config /workspace/config/cloud-init/network-config.yaml --cloud-init-user-data /workspace/config/cloud-init/user-data.yaml --os-image-tag $_OS_IMAGE_TAG"

.PHONY: help
help: ## Show help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
