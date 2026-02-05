################################################################################
# Karpenter - Kubernetes Node Autoscaler
################################################################################
#
# This file deploys Karpenter for automatic node provisioning.
#
# What is Karpenter?
# - AWS-native Kubernetes node autoscaler
# - Faster than Cluster Autoscaler (provisions nodes in seconds)
# - Right-sizes nodes based on pending pod requirements
# - Supports Spot instances with automatic interruption handling
#
# Architecture:
# - Controller runs on Fargate (no chicken-egg problem)
# - Provisions EC2 nodes into private subnets
# - Uses SQS for Spot interruption notices
#
# NodePools configured:
# - on-demand: For critical workloads (app)
# - spot: For flexible workloads (queue workers, jobs)
#
################################################################################

#------------------------------------------------------------------------------
# Karpenter Module
#------------------------------------------------------------------------------
# Using official terraform-aws-modules for Karpenter IAM setup

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.31"

  cluster_name = module.eks.cluster_name

  # Use v1 Karpenter APIs (NodePool, EC2NodeClass)
  enable_v1_permissions = true

  # Use Pod Identity (newer, recommended over IRSA)
  enable_pod_identity             = true
  create_pod_identity_association = true

  # Add SSM access to nodes for debugging via Session Manager
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

#------------------------------------------------------------------------------
# Karpenter Helm Release
#------------------------------------------------------------------------------
# Deploys Karpenter controller to the karpenter namespace

resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.1.1"

  # Don't wait - Fargate scheduling can take time
  wait = false

  values = [
    <<-EOT
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    EOT
  ]
}

#------------------------------------------------------------------------------
# EC2NodeClass - Shared Node Configuration
#------------------------------------------------------------------------------
# Defines HOW nodes are provisioned (AMI, subnets, security groups, etc.)

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      # IAM role for the nodes (created by Karpenter module)
      role: ${module.karpenter.node_iam_role_name}
      
      # Use Amazon Linux 2023 (latest recommended AMI)
      amiSelectorTerms:
        - alias: al2023@latest
      
      # Place nodes in private subnets (discovered by tag)
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}
      
      # Attach to node security group (discovered by tag)
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}
      
      # Root volume configuration
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 100Gi
            volumeType: gp3
            encrypted: true
            deleteOnTermination: true
      
      # Tags applied to EC2 instances
      tags:
        Project: ${var.project_name}
        Environment: ${var.environment}
        ManagedBy: karpenter
  YAML

  depends_on = [helm_release.karpenter]
}

#------------------------------------------------------------------------------
# On-Demand NodePool
#------------------------------------------------------------------------------
# For critical workloads that cannot tolerate interruption
# Use for: web app, API servers, databases

resource "kubectl_manifest" "karpenter_node_pool_ondemand" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: on-demand
    spec:
      # Pod template for nodes
      template:
        metadata:
          # Labels applied to nodes
          labels:
            workload-type: critical
            capacity-type: on-demand
        spec:
          # Reference the EC2NodeClass above
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          
          # Node requirements (filters)
          requirements:
            # x86_64 architecture
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            
            # Linux OS only
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            
            # On-Demand capacity (not Spot)
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            
            # Instance families (compute, memory, general purpose)
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "m", "r"]
            
            # Instance sizes
            - key: karpenter.k8s.aws/instance-size
              operator: In
              values: ["large", "xlarge", "2xlarge"]
          
          # Node expiration (recycle after 30 days)
          expireAfter: 720h
      
      # Resource limits for this pool
      limits:
        cpu: 1000    # Max 1000 vCPUs across all nodes
        memory: 2000Gi
      
      # Consolidation settings
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m
      
      # Weight (higher = preferred, try on-demand first)
      weight: 100
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}

#------------------------------------------------------------------------------
# Spot NodePool
#------------------------------------------------------------------------------
# For flexible workloads that can tolerate interruption
# Use for: queue workers, batch jobs, dev environments
# Cost savings: ~70% compared to on-demand

resource "kubectl_manifest" "karpenter_node_pool_spot" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: spot
    spec:
      template:
        metadata:
          labels:
            workload-type: flexible
            capacity-type: spot
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            
            # Spot capacity - can be interrupted with 2 min notice
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot"]
            
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "m", "r"]
            
            # Smaller sizes for Spot (more availability)
            - key: karpenter.k8s.aws/instance-size
              operator: In
              values: ["medium", "large", "xlarge"]
          
          expireAfter: 720h
      
      # Lower limits for spot pool
      limits:
        cpu: 500
        memory: 1000Gi
      
      # Aggressive consolidation for cost savings
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30s
      
      # Lower weight = fallback option
      weight: 50
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}
