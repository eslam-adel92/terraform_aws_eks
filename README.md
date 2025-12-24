# myapp Production EKS Infrastructure

Private AWS EKS cluster with Karpenter, WAFv2, and Secrets Manager integration.

## Architecture

| Component | Description                  |
| --------- | ---------------------------- |
| Region    | eu-west-1 (Ireland)          |
| VPC       | 20.0.0.0/16, 3 AZs           |
| EKS       | Private cluster v1.32        |
| Nodes     | Karpenter (On-Demand + Spot) |
| LB        | AWS Load Balancer Controller |
| Security  | WAFv2, Secrets Store CSI     |

## File Structure

```
├── versions.tf         # Terraform and provider versions
├── variables.tf        # Input variables with validation
├── providers.tf        # AWS, Kubernetes, Helm, kubectl providers
├── locals.tf          # Data sources and computed values
├── ecr.tf             # Container registry
├── vpc.tf             # VPC and subnets
├── vpc-endpoints.tf   # 13 VPC endpoints for private access
├── eks.tf             # EKS cluster with add-ons
├── karpenter.tf       # Karpenter + NodePools
├── alb-controller.tf  # AWS Load Balancer Controller
├── waf.tf             # WAFv2 Web ACL
├── secrets-csi.tf     # Secrets Store CSI Driver
├── metrics-server.tf  # Metrics Server
├── bastion.tf         # Bastion host for access
├── namespace.tf       # Application namespace
├── outputs.tf         # Output values
└── README.md          # This file
```

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

## Connect to Cluster

```bash
# Connect to bastion via SSM
aws ssm start-session --target $(terraform output -raw bastion_instance_id) --region eu-west-1

# On bastion, configure kubectl
setup-kubectl
kubectl get nodes
```

## NodePools

| Pool      | Type      | Use Case               |
| --------- | --------- | ---------------------- |
| on-demand | On-Demand | Critical (app, API)    |
| spot      | Spot      | Flexible (queue, jobs) |

Target specific pool:

```yaml
nodeSelector:
  karpenter.sh/nodepool: on-demand # or: spot
```

## WAF

ARN available via: `terraform output waf_acl_arn`

Use in Ingress:

```yaml
annotations:
  alb.ingress.kubernetes.io/wafv2-acl-arn: <arn>
```

## Modules Used

| Module                    | Purpose                    |
| ------------------------- | -------------------------- |
| terraform-aws-modules/vpc | VPC, subnets, NAT          |
| terraform-aws-modules/eks | EKS cluster, OIDC, add-ons |
| terraform-aws-modules/iam | IRSA roles                 |
