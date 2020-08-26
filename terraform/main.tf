# https://www.terraform.io/docs/configuration/terraform.html
# https://www.terraform.io/docs/backends/index.html
# https://www.terraform.io/docs/backends/types/s3.html
terraform {
  # Equivalent to ">= 0.12, < 1.0"
  required_version = "~> 0.12"
  backend "s3" {}
}

# ================================================================================
#  Providers
# ================================================================================

# https://www.terraform.io/docs/providers/aws
# https://www.terraform.io/docs/configuration/providers.html#provider-versions
# https://www.terraform.io/docs/configuration/terraform.html
provider "aws" {
  # Equivalent to ">= 2.44.0, < 3.0.0"
  version = "~> 3.0"

  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

# ================================================================================
#  Modules
# ================================================================================

module "network" {
  source = "../modules/network"

  name                = local.name
  region              = var.region
  az_count            = 3
  enable_bastion      = true
  bastion_public_key  = "${local.bastion_key_name}.pub"
  common_tags         = local.common_tags
  region_tag          = local.region_tag
  vpc_tags            = local.kubernetes_tags
  private_subnet_tags = local.kubernetes_tags
  public_subnet_tags  = local.kubernetes_tags
}

module "cluster" {
  source = "../modules/cluster"

  name                      = local.name
  region                    = var.region
  vpc_id                    = module.network.vpc.id
  subnet_ids                = [ for subnet in module.network.private_subnets: subnet.id ]
  ssh_public_key            = "${local.node_key_name}.pub"
  bastion_security_group_id = module.network.bastion.security_group_id
  enable_node_groups        = true
  enable_nodes              = false
  common_tags               = local.common_tags
  region_tag                = local.region_tag
}

# ================================================================================
#  SSH Configurations
# ================================================================================

locals {
  private_subnet_wildcards = join(" ", [
    for subnet in module.network.private_subnets: replace(subnet.cidr, "0/24", "*")
  ])
}

# https://www.terraform.io/docs/configuration/expressions.html#string-literals
# https://www.terraform.io/docs/providers/local/r/file.html
resource "local_file" "ssh_config" {
  filename = local.ssh_config_file
  content = <<-EOT
  Host bastion
    HostName ${module.network.bastion.public_ip}
    User admin
    IdentityFile ${local.bastion_key_name}.pem
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel error
  Host ${local.private_subnet_wildcards}
    User ec2-user
    IdentityFile ${local.node_key_name}.pem
    ProxyJump bastion
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel error
  EOT
}

# Remove ssh config file
# https://www.terraform.io/docs/configuration/expressions.html#string-literals
# https://www.terraform.io/docs/provisioners/null_resource.html
# https://www.terraform.io/docs/provisioners/index.html#destroy-time-provisioners
# https://www.terraform.io/docs/provisioners/local-exec.html
resource "null_resource" "ssh_cleanup" {
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${local.ssh_config_file}"
  }
}

# ================================================================================
#  Configuring kubectl
# ================================================================================

locals {
  cluster_arn = replace(module.cluster.arn, "/", "\\/")
}

# Configure kubectl
# https://www.terraform.io/docs/configuration/expressions.html#string-literals
# https://www.terraform.io/docs/provisioners/null_resource.html
# https://www.terraform.io/docs/provisioners/index.html
# https://www.terraform.io/docs/provisioners/local-exec.html
resource "null_resource" "kubectl_config" {
  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region ${var.region} --name ${module.cluster.name}
      sed -i '' "s/${local.cluster_arn}/${module.cluster.name}/g" ~/.kube/config
      kubectl config use-context ${module.cluster.name}
    EOT
  }
}

# Clean up kubectl configurations
# https://www.terraform.io/docs/configuration/expressions.html#string-literals
# https://www.terraform.io/docs/provisioners/null_resource.html
# https://www.terraform.io/docs/provisioners/index.html#destroy-time-provisioners
# https://www.terraform.io/docs/provisioners/local-exec.html
resource "null_resource" "kubectl_cleanup" {
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl config unset clusters.${module.cluster.name}
      kubectl config unset users.${module.cluster.name}
      kubectl config unset contexts.${module.cluster.name}
    EOT
  }
}
