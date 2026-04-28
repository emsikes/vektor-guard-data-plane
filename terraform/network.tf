# ----------------------------------------------------------------------------
# Networking — uses the account's default VPC.
#
# At this scope (single dev EC2 instance, public ingress disabled, all egress
# is to AWS APIs and a small set of public services), a custom VPC adds
# operational complexity without security benefit. Keeping the default VPC
# means zero custom networking code and full focus on workload security
# via the security group + SSM-only access pattern.
# ----------------------------------------------------------------------------

# Look up the account's default VPC at plan time.
data "aws_vpc" "default" {
  default = true
}

# Look up subnets in the default VPC. We'll pick one for the EC2 instance later.
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}