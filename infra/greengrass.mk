
export PROJECT_NAME = $(shell yq eval ".PROJECT_NAME" manifest.yaml)
export ECS_CLUSTER_NAME = $(shell yq eval ".ECS_CLUSTER_NAME" manifest.yaml)
export ECS_SERVICE_NAME = $(shell yq eval ".ECS_SERVICE_NAME" manifest.yaml)
export GREENGRASS_COMPONENT_NAME = $(shell yq eval ".GREENGRASS_COMPONENT_NAME" manifest.yaml)
export GREENGRASS_COMPONENT_CONFIG = $(shell yq eval ".GREENGRASS_COMPONENT_CONFIG" manifest.yaml)
export GREENGRASS_DEPLOY_CONFIG = $(shell yq eval ".GREENGRASS_DEPLOY_CONFIG" manifest.yaml)

export GREENGRASS_GROUP = $(shell yq eval ".GREENGRASS_GROUP" manifest.yaml)
export GREENGRASS_DEPLOYMENT_NAME = $(shell yq eval ".GREENGRASS_DEPLOYMENT_NAME" manifest.yaml)


.PHONY: gg-update-component
gg-update-component:  ## Updates the greengrass component
	$(ROOT)/infrastructure/gg/update_component.py \
		-e $(ENV) \
		-v $(COMPONENT_VERSION) \
		--componentfile $(GREENGRASS_COMPONENT_CONFIG) \
		--vars docker_tag=$(firstword $(DOCKER_TAGS)) \
		--component $(GREENGRASS_COMPONENT_NAME)


.PHONY: gg-deploy-component
gg-deploy-component:
	# Handles docker build and push for greengrass components.
	$(ROOT)/infrastructure/gg/update_deployment.py \
		-e $(ENV) \
		-n $(GREENGRASS_DEPLOYMENT_NAME) \
		-y $(GREENGRASS_DEPLOY_CONFIG) \
		-t thinggroup/$(GREENGRASS_GROUP) \
		-c $(GREENGRASS_COMPONENT_NAME)=$(COMPONENT_VERSION)

