[![Build Status][workflow-image]][workflow-url]

# eks-terraform

[EKS](https://aws.amazon.com/eks) is the AWS managed [Kubernetes](https://kubernetes.io) service.
For Kubernetes _masters_, you deploy a _cluster_.
For Kubernetes _nodes_, you either deploy a _node group_ that manages the nodes for you
or you manage the nodes yourself through _launch configurations_ and _auto scaling groups_.

The cluster component or control plane manages the _masters_ in the Kubernetes cluster.
It is single-tenant and deployed in one region across multiple _availability zones_.
You cannot access the _masters_ directly, but the Kubernetes API is exposed through an endpoint.

A node group is a simple and managed way for adding nodes to your cluster.
If for any reason you want to manage the nodes yourself, you need to configure _IAM_, _security groups_, _launch configurations_, and _auto scaling groups_.
You need to use a special _AMI_ built for Kubernetes nodes with the same version as your cluster version
and use a script provided in the image, so nodes can automatically join the masters in your cluster through its endpoint.

The [cluster](./modules/cluster) module in this project provides both managed and unmanaged nodes as well as the cluster.

## TO-DO

  - [ ] Use [`ignore_tags`](https://www.terraform.io/docs/providers/aws/index.html#ignore_tags) once it is generally available.

## Prerequisites

You need to have the following tools installed:

  - [terraform](https://www.terraform.io)
  - [aws](https://github.com/aws/aws-cli)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)

## Deployment

### 1. Prerequisites

You need to have the following AWS resources:

  - A **S3 Bucket** for Terraform backend state named as `terraform.<domain_name>`

### 2. Preparation

Change the directory to `terraform` and create a file named `terraform.tfvars` with the following variables set.

```
access_key  = "..."
secret_key  = "..."
region      = "..."
environment = "..."
domain      = "..."
```

### 3. Deployment

Run the following commands to deploy the resources.

```
make init keys
make plan
make apply
```

## Tear Down

You can run the following commands to tear down your deployment and clean up the resources:

```
make destroy
make clean
```

## References

  - [What is Amazon EKS?](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
  - [Worker Nodes](https://docs.aws.amazon.com/eks/latest/userguide/worker.html)
    - [Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
    - [Unmanaged Nodes](https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html)
  - [Security Group Considerations](https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html)
  - [Worker Node IAM Role](https://docs.aws.amazon.com/eks/latest/userguide/worker_node_IAM_role.html)


[workflow-url]: https://github.com/moorara/eks-terraform/actions
[workflow-image]: https://github.com/moorara/eks-terraform/workflows/Main/badge.svg
