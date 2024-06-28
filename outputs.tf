output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region us-east-1 update-kubeconfig --name ${module.eks.cluster_name}"
}

output "cluster_name" {
  description = "Cluster name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_version" {
  description = "K8s Cluster version of the EKS cluster"
  value       = module.eks.cluster_version
}

output "oidc_provider" {
  description = "EKS OIDC Provider"
  value       = module.eks.oidc_provider
}

output "eks_managed_node_groups" {
  description = "EKS managed node groups"
  value       = module.eks.eks_managed_node_groups
}

output "karpenter" {
  description = "karpenter"
  value       = module.karpenter
}