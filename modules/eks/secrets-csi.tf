################################################################################
# Secrets Store CSI Driver
################################################################################
#
# This file deploys the Secrets Store CSI Driver for Kubernetes.
#
# What is it?
# - Mounts secrets from AWS Secrets Manager directly into pods
# - Secrets appear as files in the pod's filesystem
# - Optionally syncs to Kubernetes Secrets
#
# Why use it?
# - No hardcoded secrets in container images
# - Secrets are fetched at pod startup
# - Integrates with AWS IAM for access control
#
# Usage:
# 1. Create SecretProviderClass defining which secrets to mount
# 2. Add CSI volume mount to pod spec
# 3. Pod gets secrets at /mnt/secrets (or configured path)
#
################################################################################

#------------------------------------------------------------------------------
# Secrets Store CSI Driver
#------------------------------------------------------------------------------
# Base driver that handles mounting secrets as volumes

resource "helm_release" "secrets_store_csi" {
  namespace  = "kube-system"
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = "1.4.7"

  # Enable syncing mounted secrets to Kubernetes Secrets
  # This allows using secrets as env vars, not just files
  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  # Enable automatic rotation of secrets
  set {
    name  = "enableSecretRotation"
    value = "true"
  }

  depends_on = [helm_release.karpenter]
}

#------------------------------------------------------------------------------
# AWS Secrets Manager Provider
#------------------------------------------------------------------------------
# Provider that knows how to fetch secrets from AWS Secrets Manager

resource "helm_release" "secrets_store_csi_provider_aws" {
  namespace  = "kube-system"
  name       = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = "0.3.11"

  depends_on = [helm_release.secrets_store_csi]
}
