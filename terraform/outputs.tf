output "instance_id" {
  description = "EC2 instance ID — pass to SSM Session Manager"
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.app_data.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.app_data.arn
}

output "iam_role_arn" {
  description = "IAM role attached to the EC2 instance"
  value       = aws_iam_role.app_role.arn
}

output "ssm_session_command" {
  description = "Command to connect to the instance via SSM (no SSH key needed)"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}
