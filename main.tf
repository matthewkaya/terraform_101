provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr            = var.vpc_cidr
  vpc_name            = var.vpc_name
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment         = var.environment
}

module "security" {
  source = "./modules/security"
  
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
}

module "ec2" {
  source = "./modules/ec2"
  
  instance_type          = var.instance_type
  ami_id                 = var.ami_id
  key_name               = var.key_name
  subnet_id              = module.vpc.public_subnet_ids[0]
  security_group_id      = module.security.security_group_id
  environment            = var.environment
  instance_name          = var.instance_name
}