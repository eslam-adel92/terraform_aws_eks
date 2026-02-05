################################################################################
# Bastion Host
################################################################################
#
# This file creates a Bastion host for accessing the private EKS cluster.
#
# Why a Bastion?
# - EKS cluster has NO public endpoint
# - All kubectl access must go through internal network
# - Bastion provides secure access point via AWS SSM
#
# Features:
# - Amazon Linux 2023 (latest)
# - Pre-installed: kubectl, helm
# - SSM Session Manager enabled (no SSH keys needed)
# - Minimal permissions (EKS describe only)
#
# How to connect:
#   aws ssm start-session --target <instance-id> --region eu-west-1
#   setup-kubectl
#   kubectl get nodes
#
################################################################################

#------------------------------------------------------------------------------
# Latest Amazon Linux 2023 AMI
#------------------------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

#------------------------------------------------------------------------------
# Security Group
#------------------------------------------------------------------------------
# No inbound rules needed - all access is via SSM

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion"
  description = "Bastion host security group - egress only for SSM and EKS"
  vpc_id      = module.vpc.vpc_id

  # Allow all outbound (needed for SSM agent and kubectl)
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
# IAM Role
#------------------------------------------------------------------------------
# Minimal permissions for SSM and EKS access

resource "aws_iam_role" "bastion" {
  name = "${var.project_name}-bastion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

# SSM access for Session Manager
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EKS describe permission
resource "aws_iam_role_policy" "bastion_eks" {
  name = "eks-access"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-bastion"
  role = aws_iam_role.bastion.name
}

#------------------------------------------------------------------------------
# EC2 Instance
#------------------------------------------------------------------------------

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro" # Minimal instance for admin tasks
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  # User data script to install kubectl and create helper
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Update packages
    dnf update -y
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    # Install helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Create helper script for kubectl configuration
    cat > /usr/local/bin/setup-kubectl << 'SCRIPT'
    #!/bin/bash
    echo "Configuring kubectl for ${local.cluster_name}..."
    aws eks update-kubeconfig --region ${var.aws_region} --name ${local.cluster_name}
    echo "Done! Try: kubectl get nodes"
    SCRIPT
    chmod +x /usr/local/bin/setup-kubectl
    
    echo "Bastion setup complete!"
  EOF
  )

  # Encrypted root volume
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  # IMDSv2 (more secure)
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.tags, { Name = "${var.project_name}-bastion" })

  # Don't replace instance when AMI updates
  lifecycle {
    ignore_changes = [ami]
  }
}

#------------------------------------------------------------------------------
# EKS Access Entry
#------------------------------------------------------------------------------
# Grant the bastion role admin access to the EKS cluster

resource "aws_eks_access_entry" "bastion" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.bastion.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.bastion.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}
