module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
  app_port     = 5000
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
}
module "compute" {
  source = "./modules/compute"

  project_name          = var.project_name
  environment           = var.environment
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.security.ecs_security_group_id
  execution_role_arn    = module.iam.ecs_task_execution_role_arn
  ecr_repository_url    = module.ecr.repository_url
  target_group_arn      = module.load_balancer.target_group_arn

  container_port = 5000
  cpu            = 256
  memory         = 512
  desired_count  = 2
}
module "load_balancer" {
  source = "./modules/load-balancer"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  target_port           = 5000
}
