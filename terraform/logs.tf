# ----------------------------------------------------------------------------
# CloudWatch Log Groups for the Vektor-Guard runtime workloads.
#
# One log group per workload type - splits cost and query scope so that
# 'judge worker is throwing errors' and 'inference is slow' can be
# investigated independently.
#
# Retention is set explicitly (14 days for dev). Default CloudWatch retention
# is "never expire" which is how teams accumulate silent cost.
# ----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "runtime" {
    name                = "/${local.name_prefix}/runtime"
    retention_in_days   = 14
    log_group_class     = "STANDARD"
}


resource "aws_cloudwatch_log_group" "judge" {
  name              = "/${local.name_prefix}/judge"
  retention_in_days = 14
  log_group_class   = "STANDARD"
}

resource "aws_cloudwatch_log_group" "synthetic" {
  name              = "/${local.name_prefix}/synthetic"
  retention_in_days = 14
  log_group_class   = "STANDARD"
}