variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}