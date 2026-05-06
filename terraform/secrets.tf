# ----------------------------------------------------------------------------
# AWS Secrets Manager - credential containers for the Vektor-Guard runtime.
#
# Terraform creates the secret containers and IAM-relevant metadata.
# Actual secret values are populated out-of-band via:
#   aws secretsmanager put-secret-value --secret-id <name> --secret-string <value>
#
# This keeps real credentials out of Terraform state entirely.
# ----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "databricks_pat" {
  name        = "${local.name_prefix}/databricks-pat"
  description = "Databricks personal access token for UC volume sync"

  # 7-day recovery window. Short enough to not block re-creation if we
  # destroy and recreate the secret in dev; long enough to prevent
  # accidental permanent deletion.
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret" "anthropic_api_key" {
  name        = "${local.name_prefix}/anthropic-api-key"
  description = "Anthropic API key for judge worker and synthetic generator"

  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret" "openai_api_key" {
  name        = "${local.name_prefix}/openai-api-key"
  description = "OpenAI API key for judge worker and synthetic generator"

  recovery_window_in_days = 7
}

# ----------------------------------------------------------------------------
# SSM Parameter Store - non-sensitive runtime configuration.
#
# Cheaper than Secrets Manager (free for standard tier under 10K params)
# and structured for hierarchical retrieval via GetParametersByPath.
# ----------------------------------------------------------------------------

resource "aws_ssm_parameter" "databricks_workspace_url" {
  name        = "/${local.name_prefix}/databricks/workspace-url"
  description = "Databricks workspace URL (without trailing slash)"
  type        = "String"
  value       = "PLACEHOLDER_REPLACE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "uc_catalog" {
  name        = "/${local.name_prefix}/databricks/uc-catalog"
  description = "Unity Catalog catalog name for the data plane"
  type        = "String"
  value       = "vektor_guard_dp"
}

resource "aws_ssm_parameter" "uc_schema_bronze" {
  name        = "/${local.name_prefix}/databricks/uc-schema-bronze"
  description = "Unity Catalog schema for bronze tables"
  type        = "String"
  value       = "bronze"
}

resource "aws_ssm_parameter" "uc_volume_landing" {
  name        = "/${local.name_prefix}/databricks/uc-volume-landing"
  description = "Unity Catalog volume name for the landing zone"
  type        = "String"
  value       = "landing"
}

resource "aws_ssm_parameter" "replay_dataset_id" {
  name        = "/${local.name_prefix}/replay/dataset-id"
  description = "HuggingFace dataset ID for replay agent corpus"
  type        = "String"
  value       = "theinferenceloop/vektor-guard-phase3"
}

resource "aws_ssm_parameter" "synthetic_default_rate" {
  name        = "/${local.name_prefix}/synthetic/default-rate-per-minute"
  description = "Default synthetic generator rate (events per minute) when triggered without override"
  type        = "String"
  value       = "5"
}

resource "aws_ssm_parameter" "synthetic_cost_cap_usd" {
  name        = "/${local.name_prefix}/synthetic/cost-cap-usd-per-batch"
  description = "Hard cap on USD spend per synthetic generation batch"
  type        = "String"
  value       = "5.00"
}