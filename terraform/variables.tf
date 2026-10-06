variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "ecs-zero-touch"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}