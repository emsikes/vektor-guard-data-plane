
# ----------------------------------------------------------------------------
# EC2 instance hosting the Vektor-Guard runtime services.
#
# Wires together:
# - IAM instance profile from iam.tf (Secrets Manager, S3, ECR, CloudWatch, SSM access)
# - Security group from security_group.tf (zero ingress, HTTPS-only egress)
# - Default VPC subnet from network.tf
# - CloudWatch log groups from logs.tf (logs flow here via the CloudWatch Agent)
#
# Cloud-init bootstrap installs Docker, Docker Compose, and the CloudWatch Agent.
# Actual workload (Docker images, compose file) is deployed separately via CI/CD.
# ----------------------------------------------------------------------------

# Look up the most recent Amazon Linux 2023 ARM64 AMI.
# Resolved at plan time so we always boot the freshest patched image.

data "aws_ami" "al2023_arm64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Cloud-init bootstrap script.
# Installs Docker, Docker Compose v2, and the CloudWatch Agent.
# Anything that does not need to be on every instance from boot belongs
# elsewhere (deploy-time configuration, image pulls, secret retrieval).
locals {
  bootstrap = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    # Update base system
    dnf update -y

    # Install Docker
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # Install Docker Compose v2 plugin from GitHub releases.
    # Use -f flag so HTTP errors fail loudly instead of writing error HTML to disk.
    # Verify file size after download to catch failed or redirected downloads.
    mkdir -p /usr/libexec/docker/cli-plugins
    COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest \
      | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
    curl -fSL "https://github.com/docker/compose/releases/download/v$${COMPOSE_VERSION}/docker-compose-linux-aarch64" \
      -o /usr/libexec/docker/cli-plugins/docker-compose
    test "$(stat -c%s /usr/libexec/docker/cli-plugins/docker-compose)" -gt 1000000 \
      || { echo "FATAL: docker-compose download is too small, aborting"; exit 1; }
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose

    # Install CloudWatch Agent (pre-built for AL2023 ARM64)
    dnf install -y amazon-cloudwatch-agent

    # Drop a marker file so we can verify bootstrap completion via SSM
    echo "bootstrap-completed-$(date -Iseconds)" > /var/log/vektor-guard-bootstrap.log
  EOT
}

resource "aws_instance" "runtime" {
  ami                         = data.aws_ami.al2023_arm64.id
  instance_type               = "t4g.large"
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.ec2_runtime.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_runtime.name
  associate_public_ip_address = true

  user_data                   = local.bootstrap
  user_data_replace_on_change = true

  metadata_options {
    # Require IMDSv2 (token-based) - prevents SSRF attacks from being able
    # to pivot to instance credentials.  
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${local.name_prefix}-runtime"
  }

  # Cloud-init runs asynchronously after the instance is reported running.
  # We don't await for it in Terraform, verification happens via SSM after apply.
  lifecycle {
    ignore_changes = [
      ami, # Avoid replacing the instance every time a new AL2023 AMI publishes
    ]
  }
}

