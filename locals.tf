locals {
  nightscout_secrets = jsondecode(
    data.aws_secretsmanager_secret_version.nightscout.secret_string
  )

  ssh_allowed_cidr = local.nightscout_secrets["ssh_allowed_cidr"]
  domain_name      = local.nightscout_secrets["domain_name"]
  ssh_public_key   = local.nightscout_secrets["ssh_public_key"]
}