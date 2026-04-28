# ----------------------------------------------------------------------------
# Security group for the Vektor-Guard runtime EC2 instance.
#
# Inbound: zero rules. Access is via SSM Session Manager, which uses an
# outbound HTTPS connection from the SSM agent to AWS — no inbound port
# is required.
#
# Outbound: scoped to HTTPS-only. The runtime needs to reach AWS APIs
# (Secrets Manager, S3, CloudWatch, ECR, SSM), HuggingFace Hub, the
# Anthropic and OpenAI APIs, and the Databricks workspace. All of these
# are TLS endpoints on port 443.
# ----------------------------------------------------------------------------

resource "aws_security_group" "ec2_runtime" {
  name        = "${local.name_prefix}-ec2-runtime"
  description = "Vektor-Guard runtime - no inbound, HTTPS egress only"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${local.name_prefix}-ec2-runtime"
  }
}

# Egress: HTTPS to anywhere.
resource "aws_vpc_security_group_egress_rule" "https_anywhere_ipv4" {
  security_group_id = aws_security_group.ec2_runtime.id
  description       = "HTTPS to AWS APIs and external services"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "https_anywhere_ipv6" {
  security_group_id = aws_security_group.ec2_runtime.id
  description       = "HTTPS to AWS APIs and external services (IPv6)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv6         = "::/0"
}