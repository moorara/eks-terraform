# https://www.terraform.io/docs/configuration/outputs.html

output "availability_zones" {
  value       = slice(data.aws_availability_zones.available.names, 0, local.az_len)
  description = "A list of availability zones."
}

output "vpc" {
  description = "The VPC network information."
  value = {
    id   = aws_vpc.main.id
    cidr = aws_vpc.main.cidr_block
  }
}

output "private_subnets" {
  description = "The private subnets information."
  value = [for subnet in aws_subnet.private: {
    id                = subnet.id
    cidr              = subnet.cidr_block
    availability_zone = subnet.availability_zone
  }]
}

output "public_subnets" {
  description = "The public subnets information."
  value = [for subnet in aws_subnet.public: {
    id                = subnet.id
    cidr              = subnet.cidr_block
    availability_zone = subnet.availability_zone
  }]
}

output "bastion" {
  description = "The bastion hosts information."
  value = {
    security_group_id = aws_security_group.bastion.0.id
    public_ip         = data.aws_instance.bastion.public_ip
  }
}
