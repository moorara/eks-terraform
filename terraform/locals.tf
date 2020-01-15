# https://www.terraform.io/docs/configuration/locals.html

locals {
  name      = "eks-${var.environment}"
  subdomain = format("k8s.%s.%s", var.environment, var.domain)

  bastion_key_name = format("ssh/eks-%s-%s-bastion", var.environment, var.region)
  node_key_name    = format("ssh/eks-%s-%s-node", var.environment, var.region)
  ssh_config_file  = format("ssh/eks-%s-%s-config", var.environment, var.region)

  kubernetes_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  # A map of common tags that every resource should have
  common_tags = {
    Cluster     = local.name
    Environment = var.environment
    UUID        = var.uuid
    Owner       = var.owner
    GitURL      = var.git_url
    GitBranch   = var.git_branch
    GitCommit   = var.git_commit
  }

  # A map of regional tags for resources that are not global
  region_tag = {
    Region = var.region
  }
}
