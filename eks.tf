################################################################################
# EKS Cluster
################################################################################
#
# This file creates the Amazon EKS cluster using the official module.
#
# Cluster Configuration:
# - Private only (no public endpoint)
# - OIDC enabled for IRSA (IAM Roles for Service Accounts)
# - Control plane logging enabled
# - Pod Identity Agent enabled
# - Fargate profiles for initial bootstrap (before Karpenter provision nodes)
#
# Add-ons:
# - vpc-cni: AWS CNI for pod networking
# - coredns: Kubernetes DNS
# - kube-proxy: Network proxy
# - eks-pod-identity-agent: Pod identity support
#
################################################################################

#------------------------------------------------------------------------------
# EKS Cluster Module
#------------------------------------------------------------------------------
# Using official terraform-aws-modules/eks for comprehensive EKS setup

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  # Cluster name and version
  cluster_name    = local.cluster_name
  cluster_version = var.eks_version

  #----------------------------------------------------------------------------
  # Access Configuration
  #----------------------------------------------------------------------------

  # CRITICAL: Private cluster - no public endpoint
  # All kubectl access must go through Bastion or VPN
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  #----------------------------------------------------------------------------
  # Networking
  #----------------------------------------------------------------------------

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  #----------------------------------------------------------------------------
  # Control Plane Logging
  #----------------------------------------------------------------------------
  # Logs are sent to CloudWatch Logs in /aws/eks/{cluster}/cluster

  cluster_enabled_log_types = [
    "api",               # API server logs
    "audit",             # Audit logs for security review
    "authenticator",     # IAM authentication logs
    "controllerManager", # Controller manager logs
    "scheduler"          # Scheduler decision logs
  ]

  #----------------------------------------------------------------------------
  # EKS Add-ons
  #----------------------------------------------------------------------------
  # These are AWS-managed components that run on the cluster

  cluster_addons = {
    # CoreDNS: Kubernetes DNS service
    # Configured for Fargate initially (before nodes exist)
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        computeType  = "Fargate"
        replicaCount = 2
      })
    }

    # EKS Pod Identity Agent: Newer alternative to IRSA
    eks-pod-identity-agent = {
      most_recent = true
    }

    # Kube-proxy: Network proxy on each node
    kube-proxy = {
      most_recent = true
    }

    # VPC CNI: AWS networking plugin
    vpc-cni = {
      most_recent = true
    }
  }

  #----------------------------------------------------------------------------
  # IAM / IRSA
  #----------------------------------------------------------------------------

  # Enable OIDC provider for IAM Roles for Service Accounts (IRSA)
  enable_irsa = true

  # Grant cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  #----------------------------------------------------------------------------
  # Fargate Profiles
  #----------------------------------------------------------------------------
  # Used for initial cluster bootstrap before Karpenter provisions nodes
  # Fargate runs CoreDNS and Karpenter controller pods

  fargate_profiles = {
    # Run Karpenter controller on Fargate
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
    # Run system components on Fargate
    kube_system = {
      selectors = [
        { namespace = "kube-system" }
      ]
    }
  }

  #----------------------------------------------------------------------------
  # Node Security Group Tags
  #----------------------------------------------------------------------------
  # Tag for Karpenter to discover the security group

  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.tags
}
