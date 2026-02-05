################################################################################
# Application Namespace
################################################################################
#
# This file creates the application namespace for deployment.
#
# The namespace is pre-created so that:
# - Secrets CSI can reference it
# - Network policies can be applied
# - Service accounts can be created with IRSA
#
################################################################################

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.project_name

    labels = {
      name        = var.project_name
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  depends_on = [helm_release.karpenter]
}
