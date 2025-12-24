################################################################################
# VPC Endpoints
################################################################################
#
# This file creates VPC Endpoints for private EKS cluster access.
#
# Why VPC Endpoints?
# - EKS cluster has NO public endpoint (fully private)
# - Nodes must reach AWS services via VPC Endpoints instead of NAT
# - Reduces data transfer costs (VPC Endpoints are cheaper than NAT)
# - Improves security (traffic stays within AWS network)
#
# Endpoints:
# - Interface Endpoints: Create ENIs in subnets (cost: $0.01/hr each)
# - Gateway Endpoints: Route table entries (FREE - S3, DynamoDB)
#
################################################################################

#------------------------------------------------------------------------------
# VPC Endpoints Security Group
#------------------------------------------------------------------------------
# All interface endpoints share this security group

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints"
  description = "Security group for VPC endpoints - allows HTTPS from VPC"
  vpc_id      = module.vpc.vpc_id

  # Allow HTTPS from anywhere in the VPC
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound (endpoints need to respond)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

#------------------------------------------------------------------------------
# VPC Endpoints Module
#------------------------------------------------------------------------------
# Using official terraform-aws-modules for consistent endpoint creation

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.16"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    #--------------------------------------------------------------------------
    # Container Registry Endpoints
    #--------------------------------------------------------------------------

    # ECR API - for docker login, image push/pull operations
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    # ECR Docker - for pulling container images
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    #--------------------------------------------------------------------------
    # EKS Endpoints
    #--------------------------------------------------------------------------

    # EKS API - for kubectl and SDKs to communicate with cluster
    eks = {
      service             = "eks"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    # EKS Auth - for node authentication with the cluster
    eks_auth = {
      service             = "eks-auth"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    #--------------------------------------------------------------------------
    # IAM/Security Endpoints
    #--------------------------------------------------------------------------

    # STS - for IAM role assumption (IRSA, pod identity)
    sts = {
      service             = "sts"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    # Secrets Manager - for application secrets
    secretsmanager = {
      service             = "secretsmanager"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    #--------------------------------------------------------------------------
    # SSM Endpoints (for Bastion & Node access)
    #--------------------------------------------------------------------------

    # SSM - Systems Manager agent communication
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    # SSM Messages - for Session Manager connections
    ssmmessages = {
      service             = "ssmmessages"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    # EC2 Messages - for SSM agent communication
    ec2messages = {
      service             = "ec2messages"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    #--------------------------------------------------------------------------
    # EC2 & Networking Endpoints
    #--------------------------------------------------------------------------

    # EC2 - for Karpenter to launch instances
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    # ELB - for AWS Load Balancer Controller
    elasticloadbalancing = {
      service             = "elasticloadbalancing"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    #--------------------------------------------------------------------------
    # Logging Endpoints
    #--------------------------------------------------------------------------

    # CloudWatch Logs - for container and control plane logs
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
    }

    #--------------------------------------------------------------------------
    # Gateway Endpoints (FREE)
    #--------------------------------------------------------------------------

    # S3 Gateway - for ECR image layer storage, logs, etc.
    # Gateway endpoints are free and use route tables instead of ENIs
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    }
  }

  tags = local.tags
}
