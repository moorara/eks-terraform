# ================================================================================
#  Keys
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/key_pair.html
resource "aws_key_pair" "node" {
  count = var.enable_nodes ? 1 : 0

  key_name   = "${var.name}-node"
  public_key = file(var.ssh_public_key)
}

# ================================================================================
#  IAM
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/iam_instance_profile.html
resource "aws_iam_instance_profile" "node" {
  count = var.enable_nodes ? 1 : 0

  name = "${var.name}-node"
  role = aws_iam_role.node.0.name
}

# https://www.terraform.io/docs/providers/aws/r/iam_role.html
resource "aws_iam_role" "node" {
  count = var.enable_nodes ? 1 : 0

  name = "${var.name}-node"

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
    Name = format("%s-node", var.name)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  count = var.enable_nodes ? 1 : 0

  role       = aws_iam_role.node.0.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  count = var.enable_nodes ? 1 : 0

  role       = aws_iam_role.node.0.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  count = var.enable_nodes ? 1 : 0

  role       = aws_iam_role.node.0.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ================================================================================
#  Security Groups
# ================================================================================

# https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "node" {
  count = var.enable_nodes ? 1 : 0

  name   = "${var.name}-node"
  vpc_id = var.vpc_id

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-node", var.name)
    "kubernetes.io/cluster/${aws_eks_cluster.cluster.name}" = "owned"
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# https://www.terraform.io/docs/providers/aws/r/security_group_rule.html
resource "aws_security_group_rule" "node_ingress_self" {
  count = var.enable_nodes ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.0.id
  source_security_group_id = aws_security_group.node.0.id
  description              = "Allowing nodes to communicate with each other."
}

# https://www.terraform.io/docs/providers/aws/r/security_group_rule.html
resource "aws_security_group_rule" "node_ingress_ssh" {
  count = var.enable_nodes ? 1 : 0

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.0.id
  source_security_group_id = var.bastion_security_group_id
  description              = "Allowing SSH access from bastion hosts."
}

# https://www.terraform.io/docs/providers/aws/r/security_group_rule.html
resource "aws_security_group_rule" "node_ingress_https" {
  count = var.enable_nodes ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.0.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allowing pods running extension API servers to receive communication from the cluster control plane (masters)."
}

# https://www.terraform.io/docs/providers/aws/r/security_group_rule.html
resource "aws_security_group_rule" "node_ingress_kubelet" {
  count = var.enable_nodes ? 1 : 0

  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.0.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allowing kubelets to receive communication from the cluster control plane (masters)."
}

# https://www.terraform.io/docs/providers/aws/r/security_group_rule.html
resource "aws_security_group_rule" "node_ingress_cluster" {
  count = var.enable_nodes ? 1 : 0

  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.0.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allowing pods to receive communication from the cluster control plane (masters)."
}

# https://www.terraform.io/docs/providers/aws/r/security_group_rule.html
resource "aws_security_group_rule" "node_egress_internet" {
  count = var.enable_nodes ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.0.id
  cidr_blocks       = [ "0.0.0.0/0" ]
  description       = "Allowing nodes outbound access to the internet."
}

# ================================================================================
#  Launch Templates
# ================================================================================

# https://www.terraform.io/docs/providers/aws/d/ami.html
data "aws_ami" "node" {
  count = var.enable_nodes ? 1 : 0

  most_recent = true
  owners      = [ "602401143452" ]  # Amazon EKS AMI Account ID

  filter {
    name   = "name"
    values = [ "amazon-eks-node-${aws_eks_cluster.cluster.version}-v*" ]
  }
}

# https://www.terraform.io/docs/providers/template/d/file.html
data "template_file" "node_init" {
  count = var.enable_nodes ? 1 : 0

  template = file("${path.module}/node-init.tpl")
  vars = {
    cluster_name      = aws_eks_cluster.cluster.name
    cluster_endpoint  = aws_eks_cluster.cluster.endpoint
    base64_cluster_ca = aws_eks_cluster.cluster.certificate_authority[0].data
  }
}

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-launch-templates.html
# https://www.terraform.io/docs/providers/aws/r/launch_template.html
resource "aws_launch_template" "primary" {
  count = var.enable_nodes ? 1 : 0

  name_prefix            = "${var.name}-node-"
  image_id               = data.aws_ami.node.0.id
  instance_type          = var.node_config.primary.instance_type
  key_name               = aws_key_pair.node.0.key_name
  user_data              = base64encode(data.template_file.node_init.0.rendered)

  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/block-device-mapping-concepts.html
  # https://www.terraform.io/docs/providers/aws/r/launch_template.html#block-devices
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp2"
      volume_size           = var.node_config.primary.volume_size_gb
      delete_on_termination = true
    }
  }

  # https://www.terraform.io/docs/providers/aws/r/launch_template.html#instance-profile
  iam_instance_profile {
    name = aws_iam_instance_profile.node.0.name
  }

  # https://www.terraform.io/docs/providers/aws/r/launch_template.html#network-interfaces
  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [ aws_security_group.node.0.id ]
  }

  # https://www.terraform.io/docs/providers/aws/r/launch_template.html#monitoring-1
  monitoring {
    enabled = true
  }

  tags = merge(var.common_tags, {
    Name = format("%s-node", var.name)
  })

  # https://www.terraform.io/docs/providers/aws/r/launch_template.html#tag-specifications
  tag_specifications {
    resource_type = "instance"

    tags = merge(var.common_tags, var.region_tag, {
      Name = format("%s-node", var.name)

      "kubernetes.io/cluster/${aws_eks_cluster.cluster.name}"     = "owned"
      "k8s.io/cluster-autoscaler/${aws_eks_cluster.cluster.name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled"                         = "true"
    })
  }

  # https://www.terraform.io/docs/configuration/resources.html#lifecycle-lifecycle-customizations
  lifecycle {
    create_before_destroy = true
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
      tag_specifications.0.tags["UUID"],
    ]
  }
}

# ================================================================================
#  Auto Scaling Group
# ================================================================================

# https://docs.aws.amazon.com/autoscaling/ec2/userguide/create-asg-launch-template.html
# https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html
resource "aws_autoscaling_group" "primary" {
  count = var.enable_nodes ? 1 : 0

  name_prefix               = "${var.name}-node-"
  min_size                  = var.node_config.primary.min_size
  desired_capacity          = var.node_config.primary.desired_capacity
  max_size                  = var.node_config.primary.max_size
  vpc_zone_identifier       = var.subnet_ids
  health_check_grace_period = 15

  # https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html#launch_template-1
  launch_template {
    id      = aws_launch_template.primary.0.id
    version = aws_launch_template.primary.0.latest_version
  }

  # https://www.terraform.io/docs/configuration/resources.html#lifecycle-lifecycle-customizations
  lifecycle {
    create_before_destroy = true
  }
}

# ================================================================================
#  Kubernetes Resources
# ================================================================================

# https://www.terraform.io/docs/providers/kubernetes/r/config_map.html
resource "kubernetes_config_map" "aws_auth" {
  # If node groups are also enabled, the aws-auth ConfigMap will be automatically created.
  count = !var.enable_node_groups && var.enable_nodes ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<-EOT
      - rolearn: ${aws_iam_role.node.0.arn}
        username: system:node:{{EC2PrivateDNSName}}
        groups:
          - system:bootstrappers
          - system:nodes
    EOT
  }
}
