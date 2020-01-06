# https://www.terraform.io/docs/configuration/variables.html
# https://www.terraform.io/docs/configuration/types.html

variable "name" {
  type        = string
  description = "A name for the deployment."
}

variable "region" {
  type        = string
  description = "The AWS Region for deployment."
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC network."
}

variable "subnet_ids" {
  type        = list(string)
  description = "The list of public subnet ids."
}

variable "enable_cluster_logs" {
  type        = bool
  description = "Whether or not to enable cluster control plane logging."
  default     = false
}

variable "node_group_config" {
  type = object({
    instance_types    = list(string)  # Set of instance types for worker nodes.
    disk_size_gb      = number        # Disk size of worker nodes in GB.
    desired_node_size = number        # The desired number of worker nodes.
    max_node_size     = number        # The maximum number of worker nodes.
    min_node_size     = number        # The minimum number of worker nodes.
  })

  default = {
    instance_types    = [ "t2.micro" ]
    disk_size_gb      = 32
    desired_node_size = 2
    max_node_size     = 3
    min_node_size     = 1
  }
}

variable "common_tags" {
  type        = map(string)
  description = "A map of tags to be applied to every resource."
}

variable "region_tag" {
  type        = map(string)
  description = "A map of tags to be applied to regional resources."
}
