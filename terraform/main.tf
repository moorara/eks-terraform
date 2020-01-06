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
  # Equivalent to ">= 2.43.0, < 3.0.0"
  version    = "~> 2.43"
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

# ================================================================================
#  Modules
# ================================================================================

module "network" {
  source = "../modules/network"

  name        = local.name
  region      = var.region
  az_count    = 3
  common_tags = local.common_tags
  region_tag  = local.region_tag

  vpc_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
  }
}

module "cluster" {
  source = "../modules/cluster"

  name        = local.name
  region      = var.region
  vpc_id      = module.network.vpc.id
  subnet_ids  = [ for subnet in module.network.private_subnets: subnet.id ]
  common_tags = local.common_tags
  region_tag  = local.region_tag
}

# ================================================================================
#  Configuring kubectl
# ================================================================================

locals {
  cluster_arn = replace(module.cluster.arn, "/", "\\/")
}

# Configure kubectl
# https://www.terraform.io/docs/provisioners/null_resource.html
# https://www.terraform.io/docs/provisioners/index.html
# https://www.terraform.io/docs/provisioners/local-exec.html
resource "null_resource" "configure_kubectl" {
  depends_on = [
    module.cluster,
  ]

  provisioner "local-exec" {
    command = <<EOF
      aws eks update-kubeconfig --region ${var.region} --name ${local.name}
      sed -i '' "s/${local.cluster_arn}/${local.name}/g" ~/.kube/config
    EOF
  }
}

# Clean up kubectl configurations
# https://www.terraform.io/docs/provisioners/null_resource.html
# https://www.terraform.io/docs/provisioners/index.html#destroy-time-provisioners
# https://www.terraform.io/docs/provisioners/local-exec.html
resource "null_resource" "cleanup_kubectl" {
  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
      kubectl config unset clusters.${local.name}
      kubectl config unset users.${local.name}
      kubectl config unset contexts.${local.name}
    EOF
  }
}
