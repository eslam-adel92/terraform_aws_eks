# VPC
module "vpc" {
  source = "./modules/networking"

  vpc_cidr             = var.vpc_cidr
  environment          = var.environment
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  environment     = var.environment

  depends_on = [module.vpc]
}

# EKS Node Group
module "eks_node_group" {
  source = "./modules/eks"

  cluster_name    = module.eks.cluster_name
  node_group_name = var.node_group_name
  desired_size    = var.desired_size
  min_size        = var.min_size
  max_size        = var.max_size
  instance_types  = var.instance_types
  subnet_ids      = module.vpc.private_subnet_ids
  environment     = var.environment

  depends_on = [module.eks]
}

# Bastion Host
module "bastion_host" {
  source = "./modules/bastion_host"

  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  environment      = var.environment

  depends_on = [module.vpc]
}

output "eks_cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS Cluster Endpoint"
}

output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS Cluster Name"
}