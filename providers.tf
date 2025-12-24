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

#------------------------------------------------------------------------------
# Kubernetes Provider
#------------------------------------------------------------------------------
# Configured to connect to the EKS cluster after it's created
# Uses AWS IAM authentication via the exec plugin

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  # Use AWS CLI for authentication (recommended over token)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region,
      "--profile", var.aws_profile
    ]
  }
}

#------------------------------------------------------------------------------
# Helm Provider
#------------------------------------------------------------------------------
# Used to deploy Helm charts (Karpenter, LB Controller, etc.)
# Shares authentication with Kubernetes provider

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.aws_region,
        "--profile", var.aws_profile
      ]
    }
  }
}

#------------------------------------------------------------------------------
# Kubectl Provider
#------------------------------------------------------------------------------
# Used for applying raw Kubernetes manifests (Karpenter NodePool, EC2NodeClass)
# These resources aren't native Kubernetes resources so require kubectl

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region,
      "--profile", var.aws_profile
    ]
  }
}
