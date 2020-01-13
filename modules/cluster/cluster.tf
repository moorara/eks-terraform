# ================================================================================
#  IAM
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/iam_role.html
resource "aws_iam_role" "cluster" {
  name = "${var.name}-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-cluster", var.name)
  })
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# ================================================================================
#  Security Groups
# ================================================================================

# https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "cluster" {
  name   = "${var.name}-cluster"
  vpc_id = var.vpc_id

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-cluster", var.name)
  })
}

# https://www.terraform.io/docs/providers/aws/r/security_group_rule.html
/* resource "aws_security_group_rule" "cluster_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = [ "0.0.0.0/0" ]
  description       = "Allowing cluster outbound access to the internet."
} */

# ================================================================================
#  Cluster
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_group.html
resource "aws_cloudwatch_log_group" "cluster" {
  count = var.enable_logs ? 1 : 0

  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.logs_retention_days

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-cluster", var.name)
  })
}

# https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html
# https://docs.aws.amazon.com/eks/latest/userguide/clusters.html
# https://www.terraform.io/docs/providers/aws/r/eks_cluster.html
resource "aws_eks_cluster" "cluster" {
  name                      = var.name
  role_arn                  = aws_iam_role.cluster.arn
  enabled_cluster_log_types = var.enable_logs ? [ "api", "audit" ] : []

  # https://www.terraform.io/docs/providers/aws/r/eks_cluster.html#vpc_config-1
  vpc_config {
    subnet_ids = var.subnet_ids

    # Additional cluster security groups control communications from the Kubernetes control plane to compute resources in your account.
    # Worker node security groups are applied to unmanaged worker nodes that control communications from worker nodes to the Kubernetes control plane.
    security_group_ids = [ aws_security_group.cluster.id ]

    endpoint_private_access = false
    endpoint_public_access  = true
  }

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s", var.name)
  })

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy,
  ]
}
