################################################################################
# Terraform Provider Versions
################################################################################
#
# This file defines the required Terraform version and provider versions.
# All providers are pinned to specific major versions for stability.
#
# Providers used:
# - aws: AWS resource management
# - kubernetes: Kubernetes resource management (pods, services, etc.)
# - helm: Helm chart deployments
# - kubectl: Raw Kubernetes manifest application (for Karpenter NodePools)
#
################################################################################

terraform {
  # Minimum Terraform version required
  required_version = ">= 1.5.0"

  required_providers {
    # AWS Provider - for all AWS infrastructure resources
    # https://registry.terraform.io/providers/hashicorp/aws
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }

    # Kubernetes Provider - for native K8s resources
    # https://registry.terraform.io/providers/hashicorp/kubernetes
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }

    # Helm Provider - for Helm chart deployments
    # https://registry.terraform.io/providers/hashicorp/helm
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }

    # Kubectl Provider - for raw YAML manifest application
    # Used for Karpenter NodePool/EC2NodeClass which aren't native K8s resources
    # https://registry.terraform.io/providers/alekc/kubectl
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
  }
}
