SELF_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
include $(SELF_DIR)common.mk
ifndef ($(ROOT))
	ROOT := $(shell git rev-parse --show-toplevel)
endif


$(call check_defined, TIMESTAMP, TIMESTAMP must be defined.)
$(call check_defined, ENV, ENV must be defined.)

export PROJECT_NAME = $(shell yq eval ".PROJECT_NAME" manifest.yaml)
export ECS_CLUSTER_NAME = $(shell yq eval ".ECS_CLUSTER_NAME" manifest.yaml)
export ECS_SERVICE_NAME = $(shell yq eval ".ECS_SERVICE_NAME" manifest.yaml)
export DOCKER_IMAGE_NAME = $(shell yq eval ".DOCKER_IMAGE_NAME" manifest.yaml)

# Default platform that supports x86 machines.
DOCKER_BUILD_PLATFORM ?= linux/amd64

.PHONY: docker-login
docker-login:
	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(ECR)


.PHONY: docker-build
docker-build:  ## Builds the docker container for this project
	# Dump build info to text file as part of the build
	@echo "Building Docker tags: $(DOCKER_NAME_AND_TAGS)"
	@printf '{"commit_sha":"$(CIRCLE_SHA1)","branch":"$(CIRCLE_BRANCH)","circleci_build_num":"$(CIRCLE_BUILD_NUM)", "docker_tag":"$(DOCKER_TAG)"}\n' > BUILD_INFO.json
	docker buildx build --platform $(DOCKER_BUILD_PLATFORM) --progress plain -f ./Dockerfile $(ROOT) $(foreach word,$(DOCKER_NAME_AND_TAGS),-t $(ECR)/$(word))


.PHONY: docker-build-and-push
docker-build-and-push: docker-build docker-login  ## Builds a new container and pushes to the repository
	$(foreach word,$(DOCKER_NAME_AND_TAGS),\
docker push -q $(ECR)/$(word); \
	)
	@echo "Docker push completed."


.PHONY: docker-build-and-push-and-deploy
docker-build-and-push-and-ecs-deploy: docker-build-and-push  ## Builds, pushes to ECR, deploys the container by updating the ECS task
	ecs deploy $(ECS_CLUSTER_NAME)-$(ENV) $(ECS_SERVICE_NAME)-$(ENV) --image main $(PRIMARY_DOCKER_TAG) --timeout -1


.PHONY: docker-kill-test
docker-kill-test: ## Builds the complete environment and checks if it can exit gracefully
	pytest $(ROOT)/murine_common/murine_common/tests/test_container_kill.py -v -s