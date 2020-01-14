# https://www.terraform.io/docs/configuration/terraform.html
terraform {
  # Re-usable modules should constrain only the minimum allowed version.
  required_version = ">= 0.12"
}

# ================================================================================
#  Data
# ================================================================================

# https://www.terraform.io/docs/providers/aws/d/availability_zones.html
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Total number of availability zones required
  az_len = min(
    var.az_count,
    length(data.aws_availability_zones.available.names)
  )
}

# ================================================================================
#  VPC
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/vpc.html
resource "aws_vpc" "main" {
  cidr_block           = lookup(var.vpc_cidrs, var.region)
  enable_dns_support   = true
  enable_dns_hostnames = false

  tags = merge(var.common_tags, var.region_tag, var.vpc_tags, {
    Name = var.name
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# ================================================================================
#  Subnets
# ================================================================================

# https://www.terraform.io/docs/providers/aws/r/subnet.html
resource "aws_subnet" "private" {
  count = local.az_len

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, var.region_tag, var.private_subnet_tags, {
    Name = format("%s-private-%d", var.name, 1 + count.index)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# https://www.terraform.io/docs/providers/aws/r/subnet.html
resource "aws_subnet" "public" {
  count = local.az_len

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 128 + count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, var.region_tag, var.public_subnet_tags, {
    Name = format("%s-public-%d", var.name, 1 + count.index)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# ================================================================================
#  Elastic IPs
# ================================================================================

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html
# https://www.terraform.io/docs/providers/aws/r/eip.html
resource "aws_eip" "nat" {
  count = local.az_len

  vpc = true

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-%d", var.name, 1 + count.index)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# ================================================================================
#  Gateways
# ================================================================================

# https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html
# https://www.terraform.io/docs/providers/aws/r/internet_gateway.html
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, var.region_tag, {
    Name = var.name
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
# https://www.terraform.io/docs/providers/aws/r/nat_gateway.html
resource "aws_nat_gateway" "main" {
  count = local.az_len

  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, count.index)

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-%d", var.name, 1 + count.index)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# ================================================================================
#  Route Tables
# ================================================================================

# https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html
# https://www.terraform.io/docs/providers/aws/r/route_table.html
resource "aws_route_table" "private" {
  count = local.az_len

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.main.*.id, count.index)
  }

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-private-%d", var.name, 1 + count.index)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# https://www.terraform.io/docs/providers/aws/r/route_table_association.html
resource "aws_route_table_association" "private" {
  count = local.az_len

  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

# https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html
# https://www.terraform.io/docs/providers/aws/r/route_table.html
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-public", var.name)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# https://www.terraform.io/docs/providers/aws/r/route_table_association.html
resource "aws_route_table_association" "public" {
  count = local.az_len

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# ================================================================================
#  IAM
# ================================================================================

# https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html
# https://www.terraform.io/docs/providers/aws/r/iam_instance_profile.html
resource "aws_iam_instance_profile" "vpc" {
  count = var.enable_vpc_logs ? 1 : 0

  name = "${var.name}-vpc"
  role = aws_iam_role.vpc.0.name
}

# https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html
# https://www.terraform.io/docs/providers/aws/r/iam_role.html
resource "aws_iam_role" "vpc" {
  count = var.enable_vpc_logs ? 1 : 0

  name = "${var.name}-vpc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name = format("%s-vpc", var.name)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# https://www.terraform.io/docs/providers/aws/r/iam_role_policy.html
resource "aws_iam_role_policy" "vpc" {
  count = var.enable_vpc_logs ? 1 : 0

  name = "${var.name}-vpc"
  role = aws_iam_role.vpc.0.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Resource = aws_cloudwatch_log_group.vpc.0.arn
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
    }]
  })
}

# ================================================================================
#  CloudWatch
# ================================================================================

# https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CloudWatchLogsConcepts.html
# https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_group.html
resource "aws_cloudwatch_log_group" "vpc" {
  count = var.enable_vpc_logs ? 1 : 0

  name              = "${var.name}-vpc"
  retention_in_days = 90

  tags = merge(var.common_tags, var.region_tag, {
    Name = format("%s-vpc", var.name)
  })

  lifecycle {
    # https://www.terraform.io/docs/configuration/resources.html#ignore_changes
    ignore_changes = [
      tags["UUID"],
    ]
  }
}

# https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html
# https://www.terraform.io/docs/providers/aws/r/flow_log.html
resource "aws_flow_log" "vpc" {
  count = var.enable_vpc_logs ? 1 : 0

  iam_role_arn         = aws_iam_role.vpc.0.arn
  log_destination      = aws_cloudwatch_log_group.vpc.0.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
}
