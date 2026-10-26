IMAGE := telosalliance/ubuntu-24.04
TAG   ?= $(shell date +%Y-%m-%d)

.PHONY: all image image-amd64 image-arm64 manifest lint run push

all: image

image:
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE):latest -t $(IMAGE):$(TAG) --push .
#	DOCKER_BUILDKIT=1 docker build $(ARGS) -t $(IMAGE):$(TAG) .
#	DOCKER_BUILDKIT=1 docker build $(ARGS) -t $(IMAGE):latest .

# Native per-architecture builds: run `make image-amd64` on an amd64 host and
# `make image-arm64` on an arm64 host, then `make manifest` from either one to
# combine them into the multiarch tags. This avoids qemu emulation, which breaks
# tar extraction (the Go install) for arm64 on some hosts.
image-amd64:
	docker buildx build --platform linux/amd64 -t $(IMAGE):latest-amd64 -t $(IMAGE):$(TAG)-amd64 --push .

image-arm64:
	docker buildx build --platform linux/arm64 -t $(IMAGE):latest-arm64 -t $(IMAGE):$(TAG)-arm64 --push .

manifest:
	docker buildx imagetools create -t $(IMAGE):latest $(IMAGE):latest-amd64 $(IMAGE):latest-arm64
	docker buildx imagetools create -t $(IMAGE):$(TAG) $(IMAGE):$(TAG)-amd64 $(IMAGE):$(TAG)-arm64

push: image
#	docker image push $(IMAGE):$(TAG)
#	docker image push $(IMAGE):latest

lint:
	docker run --rm -i hadolint/hadolint < Dockerfile

run:
	docker run $(ARGS) \
		--hostname $(IMAGE) \
		--env LINUX_USER=$(shell id -un) \
		--env LINUX_UID=$(shell id -u) \
		--env LINUX_GROUP=$(shell id -gn) \
		--env LINUX_GID=$(shell id -g) \
		--mount src=$(HOME),target=$(HOME),type=bind \
		-ti --rm $(IMAGE):$(TAG)
