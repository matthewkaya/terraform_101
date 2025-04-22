variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID where the instance will be launched"
  type        = string
}

variable "security_group_id" {
  description = "The security group ID to attach to the instance"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
}