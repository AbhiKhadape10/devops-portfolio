variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource naming and tags"
  type        = string
  default     = "demo-app"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "project_name must be lowercase, start with a letter, contain only letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "allowed_admin_cidr" {
  description = "CIDR block allowed for admin access (NOTE: SSH is disabled; use SSM Session Manager)"
  type        = string
  default     = "10.0.0.0/8"
}
