# Network Module

This module is used for creating basic networking infrastructure for a deployment.
This module creates `public` and `private` subnets per availability zone.
Instances launched in `private` subnets cannot be accessed from Internet.

The `bastion` host can be used for accessing private instances indirectly.
You can ssh to the bastion host and then access instances in private subnets through the bastion host.
