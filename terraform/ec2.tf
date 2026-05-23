# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for ${var.project_name} EC2"

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP — redirect to HTTPS at app layer"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NOTE: No SSH ingress! Use SSM Session Manager:
  #   aws ssm start-session --target <instance-id>

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.app_profile.name
  vpc_security_group_ids = [aws_security_group.app.id]

  # IMDSv2 ONLY — prevents SSRF → credential theft
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  # Minimal bootstrap — install Docker + CloudWatch agent
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf update -y
    dnf install -y docker amazon-cloudwatch-agent
    systemctl enable --now docker amazon-ssm-agent
    usermod -aG docker ec2-user
    echo "Bootstrap complete for ${var.project_name}" > /var/log/bootstrap.log
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "${local.name_prefix}-app"
  }
}
