# slack.mk
# ======
# Notifies deployment on a slack channel.
#

.PHONY: notify-device-deployment-slack
notify-deployment-slack:
	# Notify slack.
	$(ROOT)/infrastructure/python-utils/notify_deployment_slack.py \
		--environment "$(ENV)" \
		--hook_url "$(SLACK_SDK_CI_HOOK_URL)" \
		--build_url "$(CIRCLE_BUILD_URL)" \
		--name "$(DEPLOY_NOTIFICATION_NAME)" \
		--user "$(CIRCLE_USERNAME)" \
		--branch "$(CIRCLE_BRANCH)" \
		--pull_request "$(CIRCLE_PULL_REQUEST)" \
		--reponame "$(CIRCLE_PROJECT_REPONAME)"
