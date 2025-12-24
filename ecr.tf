################################################################################
# ECR - Elastic Container Registry
################################################################################
#
# This file creates ECR repositories for storing Docker images.
#
# Repositories created:
# - app: Main application container
# - migration: Database migration jobs
# - queue: Queue worker containers
#
# Features:
# - Image scanning on push (vulnerability detection)
# - Lifecycle policies (auto-cleanup of old images)
# - AES256 encryption at rest
#
################################################################################

#------------------------------------------------------------------------------
# ECR Repositories
#------------------------------------------------------------------------------
# Creates a repository for each item in var.ecr_repositories
# Repository names follow pattern: {project_name}/{repo_name}

resource "aws_ecr_repository" "this" {
  for_each = toset(var.ecr_repositories)

  # Repository name format: myapp-prod/app
  name = "${var.project_name}/${each.value}"

  # MUTABLE allows overwriting tags (e.g., :latest)
  # Set to IMMUTABLE for production if you want strict versioning
  image_tag_mutability = "MUTABLE"

  # Enable vulnerability scanning on every push
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encrypt images at rest (AES256 is free, KMS costs extra)
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.tags
}

#------------------------------------------------------------------------------
# Lifecycle Policies
#------------------------------------------------------------------------------
# Automatically clean up old images to reduce storage costs

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        # Rule 1: Keep only the last 30 tagged images
        rulePriority = 1
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest", "release"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = { type = "expire" }
      },
      {
        # Rule 2: Delete untagged images (failed builds) after 7 days
        rulePriority = 2
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}
