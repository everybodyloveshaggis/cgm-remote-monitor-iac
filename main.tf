terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "smdevops96_org"

    workspaces {
      name = "nightscout-infra"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_secretsmanager_secret" "nightscout" {
  name = var.nightscout_secret_name
}

data "aws_secretsmanager_secret" "dynatrace" {
  name = var.dynatrace_secret_name
}

data "aws_iam_policy_document" "nightscout_secret" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      data.aws_secretsmanager_secret.nightscout.arn,
      data.aws_secretsmanager_secret.dynatrace.arn,
    ]
  }
}

# Latest Ubuntu 22.04 LTS ARM64 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# Public ingress only. Administration uses AWS Systems Manager Session Manager.
resource "aws_security_group" "nightscout" {
  name        = "nightscout-sg"
  description = "Allow public HTTP and HTTPS for Nightscout"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nightscout-sg"
  }
}

data "aws_iam_policy_document" "nightscout_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nightscout" {
  name               = "nightscout-instance"
  assume_role_policy = data.aws_iam_policy_document.nightscout_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.nightscout.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "nightscout_secret" {
  name   = "read-nightscout-runtime-secret"
  role   = aws_iam_role.nightscout.id
  policy = data.aws_iam_policy_document.nightscout_secret.json
}

resource "aws_iam_instance_profile" "nightscout" {
  name = "nightscout-instance"
  role = aws_iam_role.nightscout.name
}

resource "aws_instance" "nightscout" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.nightscout.id]
  iam_instance_profile   = aws_iam_instance_profile.nightscout.name

  root_block_device {
    volume_size = var.volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    aws_region        = var.aws_region
    domain_name       = var.domain_name
    nightscout_secret = data.aws_secretsmanager_secret.nightscout.arn
    dynatrace_secret  = data.aws_secretsmanager_secret.dynatrace.arn
  })

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  tags = {
    Name = "nightscout"
  }
}

resource "aws_eip" "nightscout" {
  domain   = "vpc"
  instance = aws_instance.nightscout.id

  tags = {
    Name = "nightscout-eip"
  }
}
