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
  version    = "~> 2.44"
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
  bastion_key_name    = local.ssh_key_name
  common_tags         = local.common_tags
  region_tag          = local.region_tag
  vpc_tags            = local.kubernetes_tags
  private_subnet_tags = local.kubernetes_tags
  public_subnet_tags  = local.kubernetes_tags
}

module "cluster" {
  source = "../modules/cluster"

  name               = local.name
  region             = var.region
  vpc_id             = module.network.vpc.id
  subnet_ids         = [ for subnet in module.network.public_subnets: subnet.id ]
  ssh_key_name       = local.ssh_key_name
  enable_node_groups = true
  common_tags        = local.common_tags
  region_tag         = local.region_tag
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
resource "null_resource" "configure_kubectl" {
  depends_on = [
    module.cluster,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region ${var.region} --name ${local.name}
      sed -i '' "s/${local.cluster_arn}/${local.name}/g" ~/.kube/config
    EOT
  }
}

# Clean up kubectl configurations
# https://www.terraform.io/docs/configuration/expressions.html#string-literals
# https://www.terraform.io/docs/provisioners/null_resource.html
# https://www.terraform.io/docs/provisioners/index.html#destroy-time-provisioners
# https://www.terraform.io/docs/provisioners/local-exec.html
resource "null_resource" "cleanup_kubectl" {
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl config unset clusters.${local.name}
      kubectl config unset users.${local.name}
      kubectl config unset contexts.${local.name}
    EOT
  }
}
