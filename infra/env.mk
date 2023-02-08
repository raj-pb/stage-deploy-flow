# env.mk
# ======
# Handles main env vars used in all the other makefiles.
#

.DEFAULT_GOAL := help

export PROJECT_NAME = $(shell yq eval ".PROJECT_NAME" < manifest.yaml)

ifneq ($(RELEASE_VERSION),)
  # If RELEASE_VERSION is defined as an env variable, add it
  # as an additional tag. The release version should be something like:
  #   - x.y.z
  #   - 1.2.3
  #   - 0.0.1
  #   - etc.
  export DOCKER_TAGS += release-$(RELEASE_VERSION)
  export DOCKER_NAME_AND_TAGS += $(DOCKER_IMAGE_NAME):release-$(RELEASE_VERSION)
endif

ifneq ($(CIRCLE_BUILD_NUM),)
  # If running in circleci, add build number to the tag
  # the build number to the tag.
  #
  # Example: api:2022.07.06.15.55.12345

  DOCKER_NAME_AND_TAGS += $(DOCKER_IMAGE_NAME):$(shell date +"%Y.%m.%d").$(CIRCLE_BUILD_NUM)
  export DOCKER_TAGS += $(shell date +"%Y.%m.%d").$(CIRCLE_BUILD_NUM)
else
  DOCKER_NAME_AND_TAGS += $(DOCKER_IMAGE_NAME):$(TIMESTAMP)
  export DOCKER_TAGS += $(TIMESTAMP)
endif


AWS_dev_ACCOUNT_ID := 778159686710
AWS_stage_ACCOUNT_ID := 290950912221
AWS_prod_ACCOUNT_ID := 085875666852

export AWS_ACCOUNT_ID := $(AWS_$(ENV)_ACCOUNT_ID)

ECR := $(AWS_ACCOUNT_ID).dkr.ecr.us-east-1.amazonaws.com

export DOCKER_NAME_AND_TAG = $(firstword $(DOCKER_NAME_AND_TAGS))

# This tag will be used to push and referred to in the docker container definition
export PRIMARY_DOCKER_TAG = $(ECR)/$(firstword $(DOCKER_NAME_AND_TAGS))

# COMPONENT_VERSION is the actual version being built
# e.g.
#    Locally it equals the timestamp                              -- YYYY.MM.DD.HH.MM
#    In circleci it will append the circle build to the timestamp -- YYYY.MM.DD.HH.MM.CIRCLE_BUILD_NUM
#    When releasing, it will be the semantic release version      -- x.y.z, 1.0.1
export COMPONENT_VERSION = $(firstword $(RELEASE_VERSION) $(DOCKER_TAGS) $(TIMESTAMP))

.PHONY: bump-minor-version
bump-minor-version:  ## bumps a minor version; X.Y.Z -- bumps Y
	@echo "Bumping Minor Version"
	$(ROOT)/infrastructure/make-utils/bin/bump_release.sh -p $(PROJECT_NAME) -t minor

.PHONY: bump-patch-version
bump-patch-version:  ## bumps a patch version; X.Y.Z -- bumps Z
	@echo "Bumping Patch Version"
	$(ROOT)/infrastructure/make-utils/bin/bump_release.sh -p $(PROJECT_NAME) -t patch

.PHONY: bump-major-version
bump-major-version:  ## bumps a major version; X.Y.Z -- bumps X
	@echo "Bumping Major Version"
	$(ROOT)/infrastructure/make-utils/bin/bump_release.sh -p $(PROJECT_NAME) -t major


.PHONY: ec2-ssh
ec2-ssh:  ## ssh into an ec2 instance in this cluster
	$(ROOT)/infrastructure/shell-utils/ec2_ssh.sh $(ECS_CLUSTER_NAME)-$(ENV)
