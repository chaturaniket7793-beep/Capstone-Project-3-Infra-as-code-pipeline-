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