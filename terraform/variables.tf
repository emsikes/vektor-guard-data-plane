variable "aws_region" {
    description = "AWS region for all resources"
    type        = string
    default     = "us-west-2"
}

variable "project_name" {
    description = "Project identifier, used as a prefix for all resources"
    type        = string
    default     = "vektor-guard-dp"
}

variable "environment" {
    description = "Deployment environment (dev, stage, prod)"
    type        = string
    default     = "dev"

    validation {
      condition     = contains(["dev", "stage", "prod"], var.environment)
      error_message = "Environment must be dev, stage, or prod"
    }
}

variable "owner" {
    description = "Resource owner, used in tags"
    type        = string
    default     = "Matt"
}