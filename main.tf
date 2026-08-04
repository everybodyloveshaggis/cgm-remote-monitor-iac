terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Latest Ubuntu 22.04 LTS AMI (ARM64, matches t4g instance family)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "tls_private_key" "nightscout" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "nightscout" {
  key_name   = var.key_name
  public_key = tls_private_key.nightscout.public_key_openssh
}

# Saves the private key locally so you can SSH in. Keep this file safe —
# anyone with it can log into the instance. Add nightscout-key.pem to
# .gitignore if this directory is ever put under version control.
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.nightscout.private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0400"
}

resource "aws_security_group" "nightscout" {
  name        = "nightscout-sg"
  description = "Allow SSH, HTTP, HTTPS for Nightscout"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP (Caddy/Lets Encrypt challenge)"
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

resource "aws_instance" "nightscout" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.nightscout.key_name
  vpc_security_group_ids = [aws_security_group.nightscout.id]

  root_block_device {
    volume_size = var.volume_size_gb
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    domain_name = var.domain_name
  })

  tags = {
    Name = "nightscout"
  }
}

resource "aws_eip" "nightscout" {
  instance = aws_instance.nightscout.id
  domain   = "vpc"

  tags = {
    Name = "nightscout-eip"
  }
}
