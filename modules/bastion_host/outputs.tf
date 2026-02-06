################################################################################
# Outputs
################################################################################
#
# This file exports important values for use after deployment.
#
# Usage:
#   terraform output bastion_ssm_command
#   terraform output -raw cluster_endpoint
#
################################################################################

#------------------------------------------------------------------------------
# ECR Outputs
#------------------------------------------------------------------------------

output "ecr_repository_urls" {
  description = "ECR repository URLs for pushing container images"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

#------------------------------------------------------------------------------
# VPC Outputs
#------------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs (for EKS nodes)"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs (for ALB, Bastion)"
  value       = module.vpc.public_subnets
}

#------------------------------------------------------------------------------
# EKS Outputs
#------------------------------------------------------------------------------

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint (private)"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA"
  value       = module.eks.cluster_oidc_issuer_url
}

#------------------------------------------------------------------------------
# Bastion Outputs
#------------------------------------------------------------------------------

output "bastion_instance_id" {
  description = "Bastion EC2 instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_ssm_command" {
  description = "AWS CLI command to connect to bastion via SSM"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.aws_region}"
}

#------------------------------------------------------------------------------
# WAF Outputs
#------------------------------------------------------------------------------

output "waf_acl_arn" {
  description = "WAF Web ACL ARN - use in Ingress annotations"
  value       = aws_wafv2_web_acl.main.arn
}

#------------------------------------------------------------------------------
# Application Outputs
#------------------------------------------------------------------------------

output "app_namespace" {
  description = "Kubernetes namespace for application deployment"
  value       = kubernetes_namespace.app.metadata[0].name
}
