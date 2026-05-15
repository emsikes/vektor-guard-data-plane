# ----------------------------------------------------------------------------
# EventBridge Scheduler - start/stop schedules for the runtime EC2 instance.
#
# Cost optimization: instance runs 10:00 to 17:00 local time, weekdays only.
# Manual start/stop required outside that window. Aggressive scheduling
# demonstrates FinOps discipline - the friction of manual start is a feature,
# not a bug. Compute cost drops ~80% versus always-on.
#
# IAM role is scoped to just StartInstances and StopInstances on this one
# instance ARN. Same least-privilege thinking as the runtime instance role.
# ----------------------------------------------------------------------------

# Trust policy: EventBridge Scheduler can assume this role.
data "aws_iam_policy_document" "scheduler_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

# Permission policy: start and stop just this instance, nothing else.
data "aws_iam_policy_document" "scheduler_inline" {
  statement {
    sid    = "StartStopRuntimeInstance"
    effect = "Allow"
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances",
    ]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:instance/${aws_instance.runtime.id}"
    ]
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${local.name_prefix}-scheduler"
  description        = "EventBridge Scheduler role for start/stop schedules"
  assume_role_policy = data.aws_iam_policy_document.scheduler_trust.json
}

resource "aws_iam_role_policy" "scheduler_inline" {
  name   = "${local.name_prefix}-scheduler-inline"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler_inline.json
}

# Schedule: start the instance at 10:00 America/Los_Angeles, weekdays only.
resource "aws_scheduler_schedule" "start_runtime" {
  name        = "${local.name_prefix}-start-runtime"
  description = "Start the runtime EC2 instance at 10:00 local time on weekdays"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(0 10 ? * MON-FRI *)"
  schedule_expression_timezone = "America/Los_Angeles"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      InstanceIds = [aws_instance.runtime.id]
    })
  }
}

# Schedule: stop the instance at 17:00 America/Los_Angeles, weekdays only.
resource "aws_scheduler_schedule" "stop_runtime" {
  name        = "${local.name_prefix}-stop-runtime"
  description = "Stop the runtime EC2 instance at 17:00 local time on weekdays"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(0 17 ? * MON-FRI *)"
  schedule_expression_timezone = "America/Los_Angeles"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      InstanceIds = [aws_instance.runtime.id]
    })
  }
}