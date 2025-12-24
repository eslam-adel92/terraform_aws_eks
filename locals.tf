################################################################################
# Local Values
################################################################################
#
# This file contains computed values used throughout the infrastructure.
# Locals help avoid repetition and make the code more maintainable.
#
################################################################################

#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------

# Get available AZs in the region (excludes opt-in zones)
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Get current AWS account information
data "aws_caller_identity" "current" {}

# ECR Public auth token (required for pulling Karpenter images)
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

#------------------------------------------------------------------------------
# Local Values
#------------------------------------------------------------------------------

locals {
  #----------------------------------------------------------------------------
  # Naming
  #----------------------------------------------------------------------------

  # EKS cluster name - used for resource naming and Kubernetes tags
  cluster_name = "${var.project_name}-eks"

  #----------------------------------------------------------------------------
  # Networking
  #----------------------------------------------------------------------------

  # Use first 3 availability zones for redundancy
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  #----------------------------------------------------------------------------
  # Tagging
  #----------------------------------------------------------------------------

  # Common tags applied to all resources (merged with default_tags in provider)
  tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}
