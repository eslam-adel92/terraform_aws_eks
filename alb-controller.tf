################################################################################
# AWS Load Balancer Controller
################################################################################
#
# This file deploys the AWS Load Balancer Controller for Kubernetes.
#
# What does it do?
# - Provisions AWS ALB/NLB for Kubernetes Ingress/Service resources
# - Supports Kubernetes Gateway API
# - Integrates WAF for security
#
# How it works:
# - Watches for Ingress/Gateway resources
# - Creates ALB/NLB via AWS API
# - Configures target groups pointing to pods
# - Uses IRSA for AWS API authentication
#
################################################################################

#------------------------------------------------------------------------------
# IRSA Role for Load Balancer Controller
#------------------------------------------------------------------------------
# Creates IAM role that the controller assumes via service account

module "aws_lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.52"

  role_name = "${local.cluster_name}-aws-lb-controller"

  # Attach the standard LB controller policy (includes all needed permissions)
  attach_load_balancer_controller_policy = true

  # Bind to the controller's service account
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

#------------------------------------------------------------------------------
# Load Balancer Controller Helm Release
#------------------------------------------------------------------------------

resource "helm_release" "aws_lb_controller" {
  namespace  = "kube-system"
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.10.0"
  wait       = true

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  # Create service account with IRSA annotation
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_lb_controller_irsa.iam_role_arn
  }

  # Depends on Karpenter to have nodes available
  depends_on = [helm_release.karpenter]
}
