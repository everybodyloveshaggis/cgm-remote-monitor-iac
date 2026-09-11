# Nightscout on AWS — Terraform

A small, always-on Nightscout deployment: ARM-based EC2, MongoDB Atlas, Caddy, and a stable Elastic IP. The instance runs Docker itself; you do not install or operate Docker manually.

## Why this remains EC2, not ECS/Fargate

For one always-on Nightscout instance in London, `t4g.micro` is the better value. It has 2 vCPUs and 1 GiB RAM and currently costs about $6.86/month on demand before storage and public IPv4. The smallest Fargate task (0.25 vCPU / 0.5 GiB) is around $0.012/hour (about $8.76/month) before public IPv4, logs, and data transfer; it also has only half the memory. An ECS service needs an ALB, NAT, or DNS automation to provide a dependable HTTPS endpoint, which adds cost and complexity.

The current ARM64 Nightscout image supports this instance architecture. ECS becomes attractive if you need managed rolling deploys, multiple services, or automatic scaling—not for this single low-cost server.

## What Terraform creates

- A `t4g.micro` Ubuntu 22.04 ARM instance with a 10 GiB encrypted gp3 root disk.
- Elastic IP and public HTTP/HTTPS only. SSH is deliberately not exposed.
- An instance role with only Session Manager access and `GetSecretValue` on the single Nightscout secret.
- IMDSv2-required instance metadata.
- Docker, Nightscout, and Caddy provisioned at first boot.

## Required secret

Create (or update) the `nightscout-secrets` secret in AWS Secrets Manager with this JSON. The instance fetches it at boot using its IAM role; the values do not enter Terraform state or user data.

```json
{
  "MONGO_CONNECTION": "mongodb+srv://...",
  "API_SECRET": "a-long-random-secret"
}
```

Use a long randomly generated `API_SECRET`, for example `openssl rand -hex 32`. The secret name can be overridden with `nightscout_secret_name`.

Allow the instance Elastic IP in MongoDB Atlas network access. Do not put either value in `terraform.tfvars`.

## Deploy

Set your DNS A record to the future `elastic_ip` output, then apply:

```bash
terraform init
terraform apply -var='domain_name=nightscout.example.com'
```

Caddy requests a certificate after the DNS record resolves and ports 80/443 are reachable. Without `domain_name`, the service is available only over HTTP at `nightscout_url`; use a proper domain for HTTPS.

To administer the server, use the `ssm_start_session_command` output (AWS CLI and the Session Manager plugin are required locally). Useful commands once connected:

```bash
cd /home/ubuntu/nightscout
docker compose ps
docker compose logs -f
docker compose pull && docker compose up -d
```

## Existing deployment migration

Applying this revision removes the SSH key pair and port-22 ingress and replaces the EC2 instance because its bootstrap configuration changes. Atlas data is external and remains intact, but expect a short outage and Caddy to obtain a fresh certificate. Confirm the secret JSON and Atlas allow-list before applying.

## Ongoing cost notes

A public IPv4 address is billed separately by AWS at $0.005/hour (about $3.65/month), whether it is an Elastic IP or an automatically assigned public IPv4. Monitor AWS Cost Explorer and Atlas usage; database and outbound-data charges are outside this Terraform stack.

## Destroy

```bash
terraform destroy
```

This removes AWS resources created by the stack, not the Atlas database or Secrets Manager secret.