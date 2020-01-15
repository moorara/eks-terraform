# https://www.terraform.io/docs/configuration/terraform.html
terraform {
  # Re-usable modules should constrain only the minimum allowed version.
  required_version = ">= 0.12"
}

# https://www.terraform.io/docs/providers/aws/d/eks_cluster.html
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.cluster.id
}

# https://www.terraform.io/docs/providers/aws/d/eks_cluster_auth.html
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.cluster.id
}

# https://www.terraform.io/docs/providers/kubernetes/index.html
# https://www.terraform.io/docs/configuration/providers.html#provider-versions
# https://www.terraform.io/docs/configuration/terraform.html
provider "kubernetes" {
  # Equivalent to ">= 1.10.0, < 2.0.0"
  version = "~> 1.10"

  load_config_file       = false
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
