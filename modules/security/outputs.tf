output "security_group_id" {
  description = "The ID of the application security group"
  value       = aws_security_group.app_sg.id
}

output "security_group_name" {
  description = "The name of the application security group"
  value       = aws_security_group.app_sg.name
}