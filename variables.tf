variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2" # London — change if you want a different region
}

variable "instance_type" {
  description = "EC2 instance type (t4g = ARM/Graviton, cheaper; use t3.micro for x86 if you prefer)"
  type        = string
  default     = "t4g.micro"
}

variable "key_name" {
  description = "Name to give the EC2 key pair Terraform will create. The private key is saved locally as <key_name>.pem"
  type        = string
  default     = "nightscout-key"
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH in, e.g. 1.2.3.4/32 for just your IP. Do NOT leave this as 0.0.0.0/0 long-term."
  type        = string
  default     = "0.0.0.0/0"
}

variable "domain_name" {
  description = "Domain name pointed at this instance's Elastic IP, used by Caddy for automatic HTTPS. Leave blank to configure Caddy manually later."
  type        = string
  default     = ""
}

variable "volume_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}
