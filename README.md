# Nightscout on AWS — Terraform

Provisions the EC2 side of a Nightscout deployment: instance, Elastic IP, and a
security group allowing SSH/HTTP/HTTPS. Uses MongoDB Atlas (free tier) as the
database — this Terraform does not create a database, since Atlas isn't AWS.

## Before you run this

1. **Set up your MongoDB Atlas cluster** and grab the connection string — you'll
   need it after the instance boots (see step 3 below).
2. Have AWS credentials configured locally (`aws configure`, or environment
   variables / SSO profile that Terraform's AWS provider can pick up).

The SSH key pair is created for you by Terraform — no manual step needed. A
private key file (`<key_name>.pem`, e.g. `nightscout-key.pem`) is written
into this directory when you apply. Keep it safe and don't commit it to git.

## Files

- `main.tf` — provider, AMI lookup, security group, EC2 instance, Elastic IP
- `variables.tf` — inputs (region, instance type, key pair name, your IP for SSH, domain)
- `outputs.tf` — prints the Elastic IP and SSH command after apply
- `user_data.sh.tpl` — cloud-init script that installs Docker and writes the
  Nightscout `docker-compose.yml` + `Caddyfile` on first boot

## Usage

```bash
terraform init

terraform plan \
  -var="ssh_allowed_cidr=YOUR.IP.ADDR.ESS/32" \
  -var="domain_name=nightscout.yourdomain.com"

terraform apply \
  -var="ssh_allowed_cidr=YOUR.IP.ADDR.ESS/32" \
  -var="domain_name=nightscout.yourdomain.com"
```

`key_name` defaults to `nightscout-key` — only pass `-var="key_name=..."` if
you want a different name.

### Using terraform.tfvars

Instead of passing `-var` flags every time, put your values in a
`terraform.tfvars` file in this directory:

```hcl
ssh_allowed_cidr = "YOUR.IP.ADDR.ESS/32"
domain_name      = "yoursubdomain.duckdns.org"
```

Terraform picks this file up automatically — no flags needed for
`terraform plan` / `terraform apply` once it exists. Don't commit it to git
if `ssh_allowed_cidr` reveals anything you'd rather keep private.

**Important caveat:** `domain_name` is only read once, by the cloud-init
script that runs on first boot. Changing it in `terraform.tfvars` and
re-applying won't update an already-running instance — Terraform has no way
to know the Caddyfile needs editing, since it only wrote that file at boot
time, not since. If you change your domain after the fact, either edit
`~/nightscout/Caddyfile` by hand and `docker compose restart caddy` (no
Terraform involved), or taint the instance to force a full rebuild — but a
rebuild means redoing your Atlas connection string and API secret from
scratch, so the manual edit is usually less disruptive.

### No domain? Use AWS's auto-generated hostname instead

You don't need to buy a domain. AWS assigns every instance a public DNS
hostname automatically (shown in the `public_dns` output, e.g.
`ec2-3-8-45-201.compute-1.amazonaws.com`), and it stays stable since it's
tied to the Elastic IP. Let's Encrypt will issue a real cert for it — it
just needs the hostname to publicly resolve to your server, nothing more.

Because that hostname only exists once the Elastic IP is allocated, omit
`domain_name` on `apply` and set it up manually afterward (see step 5 below)
rather than trying to pass it up front.

## After `terraform apply`

1. If you used a real `domain_name`, point its A record at the `elastic_ip`
   output value. If you didn't, skip to step 5.
2. SSH in using the `ssh_command` output.
3. Edit the compose file with your real Atlas connection string and a random API secret:
   ```bash
   nano ~/nightscout/docker-compose.yml
   # set MONGO_CONNECTION and API_SECRET
   cd ~/nightscout
   docker compose up -d
   ```
4. In Atlas, restrict Network Access to just this instance's Elastic IP.
5. **If you didn't set `domain_name`:** edit `~/nightscout/Caddyfile` to use
   the `public_dns` output value in place of `:80`, then
   `docker compose restart caddy`. Caddy fetches the cert on the next request.
6. Visit `https://your-domain` or `https://<public_dns>`.

## Cleaning up

```bash
terraform destroy
```

This deletes the EC2 instance, Elastic IP, security group, and the key pair
in AWS (the local `.pem` file itself isn't auto-deleted from disk — remove
it manually if you want it fully gone). Your data is safe in Atlas either
way, since it's a separate service outside this stack.
