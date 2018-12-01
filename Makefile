SHELL := /bin/bash

AWS_REGION := ${AWS_REGION}
AWS_ACCESS_KEY_ID := ${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY := ${AWS_SECRET_ACCESS_KEY}
BUCKET := ${BUCKET}

CLOUDFLARE_EMAIL := ${CLOUDFLARE_EMAIL}
CLOUDFLARE_TOKEN := ${CLOUDFLARE_TOKEN}
CLOUDFLARE_ZONE := ${CLOUDFLARE_ZONE}
WORKER_JS := ${WORKER_JS}


CF_DIR=$(CURDIR)/terraform/cloudflare
TERRAFORM_FLAGS :=
CF_TERRAFORM_FLAGS =  -var "region=$(AWS_REGION)" \
		-var "access_key=$(AWS_ACCESS_KEY_ID)" \
		-var "secret_key=$(AWS_SECRET_ACCESS_KEY)" \
		-var "bucket=$(BUCKET)" \
		-var "cloudflare_email=$(CLOUDFLARE_EMAIL)" \
		-var "cloudflare_email=$(CLOUDFLARE_EMAIL)" \
		-var "cloudflare_token=$(CLOUDFLARE_TOKEN)" \
		-var "zone=$(CLOUDFLARE_ZONE)" \
		-var "worker_js=$(WORKER_JS)" 

.PHONY: help
help:
	@echo -e "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s :)"

.PHONY: cf-init
cf-init:
	@:$(call check_defined, AWS_REGION, Amazon Region)
	@:$(call check_defined, AWS_ACCESS_KEY_ID, Amazon Access Key ID)
	@:$(call check_defined, AWS_SECRET_ACCESS_KEY, Amazon Secret Access Key)
	@:$(call check_defined, BUCKET, s3 bucket name to store the terraform state)
	@:$(call check_defined, CLOUDFLARE_EMAIL, Cloudflare email address)
	@:$(call check_defined, CLOUDFLARE_TOKEN, Cloudflare api key)
	@:$(call check_defined, CLOUDFLARE_ZONE, Cloudflare zone)
	@:$(call check_defined, WORKER_JS, Worker JS file)
	@cd $(CF_DIR) && terraform init \
		-backend-config "bucket=$(BUCKET)" \
		-backend-config "region=$(AWS_REGION)" \
		$(CF_TERRAFORM_FLAGS)

.PHONY: cf-import
cf-import: cf-init ## Run terraform plan for Cloudflare worker.
	@cd $(CF_DIR) && terraform import $(CF_TERRAFORM_FLAGS) cloudflare_worker_script.worker zone:$(CLOUDFLARE_ZONE) 

.PHONY: cf-plan
cf-plan: cf-init ## Run terraform plan for Cloudflare worker.
	@cd $(CF_DIR) && terraform plan $(CF_TERRAFORM_FLAGS)

.PHONY: cf-apply
cf-apply: cf-init ## Run terraform apply for Cloudflare worker.
	@cd $(CF_DIR) && terraform apply $(CF_TERRAFORM_FLAGS) \
		$(TERRAFORM_FLAGS)

.PHONY: cf-destroy
cf-destroy: cf-init ## Run terraform destroy for Cloudflare worker.
	@cd $(CF_DIR) && terraform destroy \
		$(CF_TERRAFORM_FLAGS)

check_defined = \
				$(strip $(foreach 1,$1, \
				$(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
				  $(if $(value $1),, \
				  $(error Undefined $1$(if $2, ($2))$(if $(value @), \
				  required by target `$@')))

.PHONY: update
update: update-terraform ## Update terraform binary locally.

TERRAFORM_BINARY:=$(shell which terraform || echo "/usr/local/bin/terraform")
TMP_TERRAFORM_BINARY:=/tmp/terraform
.PHONY: update-terraform
update-terraform: ## Update terraform binary locally from the docker container.
	@echo "Updating terraform binary..."
	$(shell docker run --rm --entrypoint bash r.j3ss.co/terraform -c "cd \$\$$(dirname \$\$$(which terraform)) && tar -Pc terraform" | tar -xvC $(dir $(TMP_TERRAFORM_BINARY)) > /dev/null)
	sudo mv $(TMP_TERRAFORM_BINARY) $(TERRAFORM_BINARY)
	sudo chmod +x $(TERRAFORM_BINARY)
	@echo "Update terraform binary: $(TERRAFORM_BINARY)"
	@terraform version

.PHONY: test
test: shellcheck ## Runs the tests on the repository.

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

.PHONY: shellcheck
shellcheck: ## Runs the shellcheck tests on the scripts.
	docker run --rm -i $(DOCKER_FLAGS) \
		--name shellcheck \
		-v $(CURDIR):/usr/src:ro \
		--workdir /usr/src \
		r.j3ss.co/shellcheck ./test.sh

