# ----------------------------------------------------------------------------
# Terraform outputs - structured access to commonly-needed values.
#
# Consumed by CI/CD scripts, debugging shell aliases, and future modules
# that need to reference resources from this stack.
#
# Values marked sensitive will be redacted from terraform output unless
# the user explicitly requests them via -raw flag.
# ----------------------------------------------------------------------------

# Compute identity
output "ec2_instance_id" {
  description = "EC2 instance ID for the runtime"
  value       = aws_instance.runtime.id
}

output "ec2_instance_arn" {
  description = "EC2 instance ARN for the runtime"
  value       = aws_instance.runtime.arn
}

output "ec2_instance_private_ip" {
  description = "Private IPv4 of the runtime instance"
  value       = aws_instance.runtime.private_ip
}

# Network identity
output "vpc_id" {
  description = "VPC ID hosting the runtime"
  value       = data.aws_vpc.default.id
}

output "security_group_id" {
  description = "Security group ID attached to the runtime"
  value       = aws_security_group.ec2_runtime.id
}

# IAM
output "ec2_runtime_role_arn" {
  description = "ARN of the IAM role attached to the runtime instance"
  value       = aws_iam_role.ec2_runtime.arn
}

output "ec2_runtime_instance_profile_arn" {
  description = "ARN of the instance profile attached to the runtime"
  value       = aws_iam_instance_profile.ec2_runtime.arn
}

output "scheduler_role_arn" {
  description = "ARN of the IAM role used by EventBridge Scheduler"
  value       = aws_iam_role.scheduler.arn
}

# Storage
output "events_bucket_name" {
  description = "S3 bucket name for event archive"
  value       = aws_s3_bucket.events.id
}

output "events_bucket_arn" {
  description = "S3 bucket ARN for event archive"
  value       = aws_s3_bucket.events.arn
}

# Secrets - we expose the names, not the values
output "secret_databricks_pat_name" {
  description = "Secrets Manager secret name for the Databricks PAT"
  value       = aws_secretsmanager_secret.databricks_pat.name
}

output "secret_anthropic_api_key_name" {
  description = "Secrets Manager secret name for the Anthropic API key"
  value       = aws_secretsmanager_secret.anthropic_api_key.name
}

output "secret_openai_api_key_name" {
  description = "Secrets Manager secret name for the OpenAI API key"
  value       = aws_secretsmanager_secret.openai_api_key.name
}

# Observability
output "log_group_runtime" {
  description = "CloudWatch log group for runtime services"
  value       = aws_cloudwatch_log_group.runtime.name
}

output "log_group_judge" {
  description = "CloudWatch log group for judge worker"
  value       = aws_cloudwatch_log_group.judge.name
}

output "log_group_synthetic" {
  description = "CloudWatch log group for synthetic generator"
  value       = aws_cloudwatch_log_group.synthetic.name
}

# Scheduler
output "scheduler_start_arn" {
  description = "ARN of the start-runtime schedule"
  value       = aws_scheduler_schedule.start_runtime.arn
}

output "scheduler_stop_arn" {
  description = "ARN of the stop-runtime schedule"
  value       = aws_scheduler_schedule.stop_runtime.arn
}

# Region (handy reference for scripts)
output "aws_region" {
  description = "AWS region for this deployment"
  value       = var.aws_region
}