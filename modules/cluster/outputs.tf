# https://www.terraform.io/docs/configuration/outputs.html

output "name" {
  value       = aws_eks_cluster.cluster.id
  description = "The name of EKS cluster."
}

output "arn" {
  value       = aws_eks_cluster.cluster.arn
  description = "The Amazon Resource Name (ARN) of the cluster."
}

output "version" {
  value       = aws_eks_cluster.cluster.version
  description = "The version of the Kubernetes cluster."
}

output "status" {
  value       = aws_eks_cluster.cluster.status
  description = "The status of the Kubernetes cluster."
}

output "endpoint" {
  value       = aws_eks_cluster.cluster.endpoint
  description = "The endpoint for API server of the Kubernetes cluster."
}

output "certificate_authority" {
  value       = aws_eks_cluster.cluster.certificate_authority[0].data
  description = "The certificate authority data for the Kubernetes cluster (base64-encoded)."
}

output "kubeconfig" {
  description = "The kubectl configuration for accessing the cluster."
  value = <<-EOT
  apiVersion: v1
  kind: Config
  current-context: ${var.name}
  contexts:
    - name: ${var.name}
      context:
        cluster: ${var.name}-cluster
        user: ${var.name}-user
  clusters:
    - name: ${var.name}-cluster
      cluster:
        server: ${aws_eks_cluster.cluster.endpoint}
        certificate-authority-data: ${aws_eks_cluster.cluster.certificate_authority[0].data}
  users:
    - name: ${var.name}-user
      user:
        exec:
          apiVersion: client.authentication.k8s.io/v1alpha1
          command: aws
          args:
            - eks
            - get-token
            - --region
            - ${var.region}
            - --cluster-name
            - ${var.name}
  EOT
}

output "aws_auth" {
  description = "The aws-auth ConfigMap for nodes to join the cluster."
  value = var.enable_nodes == false ? "" : <<-EOT
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: aws-auth
    namespace: kube-system
  data:
    mapRoles: |
      - rolearn: ${aws_iam_role.node.0.arn}
        username: system:node:{{EC2PrivateDNSName}}
        groups:
          - system:bootstrappers
          - system:nodes
  EOT
}
