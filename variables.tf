variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.micro"
}

variable "domain_name" {
  description = "DNS name used by Caddy for HTTPS; leave empty for HTTP-only access by IP"
  type        = string
  default     = ""
}

variable "nightscout_secret_name" {
  description = "Secrets Manager secret containing MONGO_CONNECTION and API_SECRET"
  type        = string
  default     = "nightscout-secrets"
}

variable "dynatrace_secret_name" {
  description = "Secrets Manager secret containing DYNATRACE_ENV_URL and DYNATRACE_PLATFORM_TOKEN"
  type        = string
  default     = "dynatrace-secrets"
}

variable "volume_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 10
}
