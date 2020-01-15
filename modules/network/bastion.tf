# ================================================================================
#  Keys
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/key_pair.html
resource "aws_key_pair" "bastion" {
  count = var.enable_bastion ? 1 : 0

  key_name   = "${var.name}-bastion"
  public_key = file(var.bastion_public_key)
}

# ================================================================================
#  IAM
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/iam_instance_profile.html
resource "aws_iam_instance_profile" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name = "${var.name}-bastion"
  role = aws_iam_role.bastion.0.name
}

# https://www.terraform.io/docs/providers/aws/r/iam_role.html
resource "aws_iam_role" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name = "${var.name}-bastion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name = format("%s-bastion", var.name)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html
resource "aws_iam_role_policy" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name = "${var.name}-bastion"
  role = aws_iam_role.bastion.0.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Resource = "*"
      Action: [
        "ec2:Describe*"
      ]
    }]
  })
}

# ================================================================================
#  Security Group
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name   = "${var.name}-bastion"
  vpc_id = aws_vpc.main.id

  # Outgoing: All protocols inside the VPC
  /* egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ aws_vpc.main.cidr_block ]
  } */

  # Outgoing: All protocols to the Internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  # Incoming: ICMP inside the VPC
  ingress {
    to_port     = -1
    from_port   = -1
    protocol    = "icmp"
    cidr_blocks = [ aws_vpc.main.cidr_block ]
  }

  # Incoming: All protocols inside the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ aws_vpc.main.cidr_block ]
  }

  # Incoming: SSH from trusted sources
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_whitelist
  }

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-bastion", var.name)
  })

  # https://www.terraform.io/docs/configuration/resources.html#lifecycle-lifecycle-customizations
  lifecycle {
    create_before_destroy = true
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# ================================================================================
#  Launch Templates
# ================================================================================

# https://www.terraform.io/docs/providers/aws/d/ami.html
data "aws_ami" "debian" {
  most_recent = true
  owners      = [ "379101102735" ]

  filter {
    name   = "name"
    values = [ "debian-stretch-hvm-x86_64-gp2-*" ]
  }

  filter {
    name   = "virtualization-type"
    values = [ "hvm" ]
  }
}

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-launch-templates.html
# https://www.terraform.io/docs/providers/aws/r/launch_template.html
resource "aws_launch_template" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                                 = "${var.name}-bastion"
  image_id                             = data.aws_ami.debian.id
  instance_type                        = "t2.micro"
  key_name                             = aws_key_pair.bastion.0.key_name
  instance_initiated_shutdown_behavior = "terminate"

  # https://www.terraform.io/docs/providers/aws/r/launch_template.html#instance-profile
  iam_instance_profile {
    name = aws_iam_instance_profile.bastion.0.name
  }

  # https://www.terraform.io/docs/providers/aws/r/launch_template.html#network-interfaces
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [ aws_security_group.bastion.0.id ]
  }

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-bastion", var.name)
  })

  # https://www.terraform.io/docs/providers/aws/r/launch_template.html#tag-specifications
  tag_specifications {
    resource_type = "instance"

    tags = merge(var.common_tags, var.region_tag, {
      Name = format("%s-bastion", var.name)
    })
  }

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
      tag_specifications.0.tags["UUID"],
    ]
  }
}

# ================================================================================
#  Auto Scaling Groups
# ================================================================================

# https://docs.aws.amazon.com/autoscaling/ec2/userguide/create-asg-launch-template.html
# https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html
resource "aws_autoscaling_group" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                 = "${var.name}-bastion"
  min_size             = 1
  desired_capacity     = 1
  max_size             = 1
  vpc_zone_identifier  = slice(aws_subnet.public.*.id, 0, local.az_len)

  # https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html#launch_template-1
  launch_template {
    id      = aws_launch_template.bastion.0.id
    version = aws_launch_template.bastion.0.latest_version
  }
}

# https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-instances.html
# https://www.terraform.io/docs/providers/aws/d/instance.html
data "aws_instance" "bastion" {
  depends_on = [ aws_autoscaling_group.bastion ]

  filter {
    name   = "tag:Name"
    values = [ "${var.name}-bastion" ]
  }
}
