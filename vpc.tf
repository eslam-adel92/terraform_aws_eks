################################################################################
# VPC - Virtual Private Cloud
################################################################################
#
# This file creates the network infrastructure for the EKS cluster.
#
# Architecture:
# - 1 VPC with DNS hostnames enabled
# - 3 Public subnets (for ALB, NAT Gateway, Bastion)
# - 3 Private subnets (for EKS nodes, pods)
# - 1 NAT Gateway (single for cost efficiency)
# - S3 Gateway Endpoint
# - 12+ Interface Endpoints for private EKS access
#
# Subnet Tags:
# - Public subnets: kubernetes.io/role/elb = 1 (for public ALB)
# - Private subnets: kubernetes.io/role/internal-elb = 1 (for internal LB)
# - Private subnets: karpenter.sh/discovery = {cluster} (for Karpenter)
#
################################################################################

#------------------------------------------------------------------------------
# VPC Module
#------------------------------------------------------------------------------
# Using official terraform-aws-modules/vpc for battle-tested VPC setup

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  # Deploy across 3 AZs for high availability
  azs = local.azs

  # Subnet CIDR calculation:
  # /16 VPC divided into /19 subnets (8192 IPs each)
  # Private: 20.0.96.0/19, 20.0.128.0/19, 20.0.160.0/19
  # Public:  20.0.0.0/19, 20.0.32.0/19, 20.0.64.0/19
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 3, k + 3)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 3, k)]

  # NAT Gateway settings
  # Single NAT saves ~$30/month vs 3 NATs, acceptable for non-HA outbound
  enable_nat_gateway = true
  single_nat_gateway = true

  # Required for private EKS endpoint resolution
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required by AWS Load Balancer Controller
  # These tell the controller which subnets to use for ALBs
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  # Tags required by:
  # - AWS LB Controller (internal-elb)
  # - Karpenter (karpenter.sh/discovery)
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "karpenter.sh/discovery"                      = local.cluster_name
  }

  tags = local.tags
}
