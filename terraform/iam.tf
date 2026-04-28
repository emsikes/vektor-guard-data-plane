# ----------------------------------------------------------------------------
# IAM role and instance profile for the Vektor-Guard runtime EC2 instance.
#
# - Trust policy: only the EC2 service can assume this role.
# - Managed policy: AmazonSSMManagedInstanceCore (Session Manager + Run Command).
# - Inline policy: project-scoped least-privilege for Secrets Manager,
#   Parameter Store, S3 event archive, ECR image pulls, and CloudWatch.
# ----------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_runtime" {
  name               = "${local.name_prefix}-ec2-runtime"
  description        = "Instance role for the Vektor-Guard runtime EC2"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_instance_profile" "ec2_runtime" {
  name = "${local.name_prefix}-ec2-runtime"
  role = aws_iam_role.ec2_runtime.name
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "ec2_runtime_inline" {
  statement {
    sid    = "ReadRuntimeSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${local.name_prefix}/*"
    ]
  }

  statement {
    sid    = "ReadRuntimeParams"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${local.name_prefix}/*"
    ]
  }

  statement {
    sid    = "WriteEventArchive"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]
    resources = [
      "arn:aws:s3:::${local.name_prefix}-events/*"
    ]
  }

  statement {
    sid    = "PullEcrImages"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "WriteObservability"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_runtime_inline" {
  name   = "${local.name_prefix}-ec2-runtime-inline"
  role   = aws_iam_role.ec2_runtime.id
  policy = data.aws_iam_policy_document.ec2_runtime_inline.json
}