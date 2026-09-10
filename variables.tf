variable "aws_region" {
  description = "AWS region to deploy into"

  type = string

  default = "eu-west-2"
}

variable "instance_type" {
  description = "EC2 instance type"

  type = string

  default = "t4g.micro"
}

variable "key_name" {
  description = "AWS EC2 key pair name"

  type = string

  default = "nightscout-key"
}

variable "ssh_public_key" {
  description = "OpenSSH public key used to access the Nightscout instance"

  type      = string
  sensitive = true
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH to the instance, ideally your public IP /32"

  type = string
}

variable "domain_name" {
  description = "DNS name used by Caddy for HTTPS"

  type = string

  default = ""
}

variable "volume_size_gb" {
  description = "Root EBS volume size in GB"

  type = number

  default = 20
}