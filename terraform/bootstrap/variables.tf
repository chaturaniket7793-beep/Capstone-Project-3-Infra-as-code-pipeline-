variable "aws_region" {
  description = "AWS region for Terraform state infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecs-zero-touch"
}