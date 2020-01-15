# ================================================================================
#  Keys
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/key_pair.html
resource "aws_key_pair" "node_group" {
  count = var.enable_node_groups ? 1 : 0

  key_name   = "${var.name}-node-group"
  public_key = file(var.ssh_public_key)
}

# ================================================================================
#  IAM
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/iam_role.html
resource "aws_iam_role" "node_group" {
  count = var.enable_node_groups ? 1 : 0

  name = "${var.name}-node-group"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name = format("%s-node-group", var.name)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  count = var.enable_node_groups ? 1 : 0

  role       = aws_iam_role.node_group.0.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  count = var.enable_node_groups ? 1 : 0

  role       = aws_iam_role.node_group.0.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  count = var.enable_node_groups ? 1 : 0

  role       = aws_iam_role.node_group.0.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ================================================================================
#  Node Groups
# ================================================================================

# https://docs.aws.amazon.com/eks/latest/userguide/worker.html
# https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html
# https://www.terraform.io/docs/providers/aws/r/eks_node_group.html
resource "aws_eks_node_group" "primary" {
  count = var.enable_node_groups ? 1 : 0

  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]

  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = var.name
  node_role_arn   = aws_iam_role.node_group.0.arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.node_group_config.primary.instance_types
  disk_size       = var.node_group_config.primary.disk_size_gb

  # https://www.terraform.io/docs/providers/aws/r/eks_node_group.html#scaling_config-configuration-block
  scaling_config {
    min_size     = var.node_group_config.primary.min_node_size
    desired_size = var.node_group_config.primary.desired_node_size
    max_size     = var.node_group_config.primary.max_node_size
  }

  # https://www.terraform.io/docs/providers/aws/r/eks_node_group.html#remote_access-configuration-block
  remote_access {
    ec2_ssh_key               = aws_key_pair.node_group.0.key_name
    source_security_group_ids = [ var.bastion_security_group_id ]
  }

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-node-group", var.name)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}
