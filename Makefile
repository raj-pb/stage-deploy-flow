
TIMESTAMP := $(shell date +"%Y.%m.%d.%H.%M")
ROOT := $(shell git rev-parse --show-toplevel)
ENV ?= dev


# the '-' prefix makes it ignore import errors (i.e. when run within a docker container)
-include $(ROOT)/infra/env.mk
-include $(ROOT)/infra/docker.mk
-include $(ROOT)/infra/slack.mk