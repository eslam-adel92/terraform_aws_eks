################################################################################
# Metrics Server
################################################################################
#
# This file deploys the Kubernetes Metrics Server.
#
# What is it?
# - Collects CPU and memory metrics from nodes and pods
# - Required for Horizontal Pod Autoscaler (HPA)
# - Enables `kubectl top nodes` and `kubectl top pods`
#
# Note: Metrics Server provides real-time metrics only.
# For historical metrics, use Prometheus or CloudWatch Container Insights.
#
################################################################################

resource "helm_release" "metrics_server" {
  namespace  = "kube-system"
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"

  # Required for private cluster - prefer InternalIP for kubelet connection
  set {
    name  = "args[0]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  depends_on = [helm_release.karpenter]
}
