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
  name = "nightscout-secrets"
}

data "aws_secretsmanager_secret_version" "nightscout" {
  secret_id = data.aws_secretsmanager_secret.nightscout.id
}


# Latest Ubuntu 22.04 LTS ARM64 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

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

# ---------------------------------------------------------
# SSH
# ---------------------------------------------------------

resource "aws_key_pair" "nightscout" {
  key_name   = var.key_name
  public_key = local.ssh_public_key

  tags = {
    Name = "nightscout"
  }
}

# ---------------------------------------------------------
# Security Group
# ---------------------------------------------------------

resource "aws_security_group" "nightscout" {
  name        = "nightscout-sg"
  description = "Allow SSH, HTTP and HTTPS for Nightscout"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = [
      local.ssh_allowed_cidr
    ]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
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

# ---------------------------------------------------------
# EC2
# ---------------------------------------------------------

resource "aws_instance" "nightscout" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  key_name = aws_key_pair.nightscout.key_name

  vpc_security_group_ids = [
    aws_security_group.nightscout.id
  ]

  root_block_device {
    volume_size = var.volume_size_gb
    volume_type = "gp3"

    encrypted = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    domain_name = local.domain_name
  })

  user_data_replace_on_change = true

  tags = {
    Name = "nightscout"
  }
}

# ---------------------------------------------------------
# Elastic IP
# ---------------------------------------------------------

resource "aws_eip" "nightscout" {
  domain = "vpc"

  instance = aws_instance.nightscout.id

  tags = {
    Name = "nightscout-eip"
  }
}