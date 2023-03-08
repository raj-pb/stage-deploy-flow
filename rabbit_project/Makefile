
TIMESTAMP := $(shell date +"%Y.%m.%d.%H.%M")
ROOT := $(shell git rev-parse --show-toplevel)
ENV ?= dev
CURRENT_VERSION = $(shell cat VERSION)


# the '-' prefix makes it ignore import errors (i.e. when run within a docker container) emo
-include $(ROOT)/infra/env.mk
-include $(ROOT)/infra/docker.mk

all:
	@echo $(CURRENT_VERSION)+build-$(TIMESTAMP)-$(shell whoami)