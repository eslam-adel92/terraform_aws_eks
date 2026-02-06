################################################################################
# Provider Configuration
################################################################################
#
# This file configures all Terraform providers used in this infrastructure.
#
# Providers configured:
# - AWS (default): Main region for all resources
# - AWS (virginia): us-east-1 for ECR Public access (required for Karpenter)
# - Kubernetes: Connects to EKS cluster after creation
# - Helm: Deploys Helm charts to EKS
# - Kubectl: Applies raw Kubernetes manifests
#
################################################################################

#------------------------------------------------------------------------------
# AWS Provider - Primary Region
#------------------------------------------------------------------------------
# This is the main AWS provider for all resources in eu-west-1

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Default tags applied to ALL resources created by this provider
  # Additional resource-specific tags can be added in each resource block
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

#------------------------------------------------------------------------------
# AWS Provider - Virginia Region
#------------------------------------------------------------------------------
# Required for ECR Public access (Karpenter images are in ECR Public)
# ECR Public only operates in us-east-1

provider "aws" {
  alias   = "virginia"
  region  = "us-east-1"
  profile = var.aws_profile
}