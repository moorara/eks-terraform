region := $(shell cat terraform.tfvars | grep region | grep -oe '".*"')
environment := $(shell cat terraform.tfvars | grep environment | grep -oe '".*"')
domain := $(shell cat terraform.tfvars | grep domain | grep -oe '".*"')

uuid := $(shell uuidgen)
owner := $(shell whoami)
branch := $(shell git rev-parse --abbrev-ref HEAD)
commit := $(shell git rev-parse --short HEAD)

ssh_path := ssh
bastion_key := $(ssh_path)/eks-$(environment)-$(region)-bastion
node_key := $(ssh_path)/eks-$(environment)-$(region)-node


.PHONY: clean
clean:
	@ rm -rf $(ssh_path) \
	  rm -rf .terraform terraform.tfstate terraform.tfstate.backup

.PHONY: keys
keys:
	@ mkdir -p ${ssh_path}
	@ ssh-keygen -f $(bastion_key) -t rsa -N '' 1> /dev/null && \
	  chmod 400 $(bastion_key) && \
	  mv $(bastion_key) $(bastion_key).pem
	@ ssh-keygen -f $(node_key) -t rsa -N '' 1> /dev/null && \
	  chmod 400 $(node_key) && \
	  mv $(node_key) $(node_key).pem

.PHONY: init
init:
	@ terraform init \
	    -backend-config="bucket=terraform.$(domain)" \
	    -backend-config="key=$(environment)/infra.tfstate" \
	    -backend-config="region=us-east-1"

.PHONY: validate
validate:
	@ terraform validate

.PHONY: plan
plan:
	@ terraform plan \
	    -var uuid=$(uuid) \
	    -var owner=$(owner) \
	    -var git_branch=$(branch) \
	    -var git_commit=$(commit)

.PHONY: apply
apply:
	@ terraform apply \
	    -var uuid=$(uuid) \
	    -var owner=$(owner) \
	    -var git_branch=$(branch) \
	    -var git_commit=$(commit)

.PHONY: destroy
destroy:
	@ terraform destroy \
	    -var uuid=$(uuid) \
	    -var owner=$(owner) \
	    -var git_branch=$(branch) \
	    -var git_commit=$(commit)
