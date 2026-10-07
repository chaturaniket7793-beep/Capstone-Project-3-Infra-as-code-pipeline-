terraform {
  required_version = ">= 1.15.3"

  backend "s3" {
    bucket         = "ecs-zero-touch-terraform-state"
    key            = "ecs-zero-touch/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "ecs-zero-touch-terraform-locks"
    use_lockfile   = true
    encrypt        = true
  }
}