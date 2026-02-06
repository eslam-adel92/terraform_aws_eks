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