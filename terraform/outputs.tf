# https://www.terraform.io/docs/configuration/outputs.html

output "availability_zones" {
  value       = module.network.availability_zones
  description = "A list of availability zones."
}

output "vpc" {
  value       = module.network.vpc
  description = "The VPC network information."
}

output "private_subnets" {
  value       = module.network.private_subnets
  description = "The private subnets information."
}

output "public_subnets" {
  value       = module.network.public_subnets
  description = "The public subnets information."
}

output "cluster_status" {
  value       = module.cluster.status
  description = "The status of the Kubernetes cluster."
}
