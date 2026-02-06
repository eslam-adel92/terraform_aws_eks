################################################################################
# Input Variables
################################################################################
#
# This file contains all configurable variables for the infrastructure.
# Variables are organized by category for easy discovery.
#
# Usage:
#   terraform apply -var="project_name=my-project"
#   
# Or create a terraform.tfvars file:
#   project_name = "my-project"
#   aws_region   = "eu-west-1"
#
################################################################################

#------------------------------------------------------------------------------
# AWS Configuration
#------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name for authentication"
  type        = string
  default     = "myapp"
}

#------------------------------------------------------------------------------
# Project Identification
#------------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource naming and tagging. This will be prefixed to all resource names."
  type        = string
  default     = "myapp-prod"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development."
  }
}

#------------------------------------------------------------------------------
# Networking
#------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be /16 or larger to accommodate subnets."
  type        = string
  default     = "20.0.0.0/16"
}

#------------------------------------------------------------------------------
# Additional Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
