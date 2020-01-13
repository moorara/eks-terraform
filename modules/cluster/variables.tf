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

variable "enable_logs" {
  type        = bool
  description = "Whether or not to enable cluster control plane logging."
  default     = false
}

variable "logs_retention_days" {
  type        = number
  description = "The number of days to retain the cluster log events."
  default     = 90
}

variable "ssh_key_name" {
  type        = string
  description = "The name of SSH key (without extension) for connecting to nodes (node groups)."
}

variable "ssh_whitelist" {
  type        = list(string)
  description = "A list of trusted CIDR blocks for SSH access (node groups)."
  default     = [ "0.0.0.0/0" ]
}

variable "enable_node_groups" {
  type        = bool
  description = "Whehter or not to enable node groups (managed nodes)."
  default     = true
}

variable "node_group_config" {
  description = "A map of objects each having the configurations for one node group."

  type = map(
    object({
      instance_types    = list(string)  # List of instance types for nodes in node groups.
      disk_size_gb      = number        # Disk size of nodes in node groups in GB.
      min_node_size     = number        # The minimum number of nodes in node groups.
      desired_node_size = number        # The desired number of nodes in node groups.
      max_node_size     = number        # The maximum number of nodes in node groups.
    })
  )

  default = {
    primary = {
      instance_types    = [ "t2.micro" ]
      disk_size_gb      = 32
      min_node_size     = 1
      desired_node_size = 3
      max_node_size     = 5
    }
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
