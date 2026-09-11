#!/bin/bash

set -euo pipefail
exec > >(tee /var/log/nightscout-user-data.log | logger -t nightscout-user-data -s 2>/dev/console) 2>&1

echo "Starting Nightscout bootstrap..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl jq awscli

curl -fsSL https://get.docker.com | sh
apt-get install -y docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

install -d -m 0750 -o ubuntu -g ubuntu /home/ubuntu/nightscout
cd /home/ubuntu/nightscout

# Fetch at boot using the instance role. The secret never enters Terraform state
# or the user-data template.
for attempt in {1..12}; do
  if secret_json="$(aws secretsmanager get-secret-value \
    --region '${aws_region}' \
    --secret-id '${nightscout_secret}' \
    --query SecretString \
    --output text)"; then
    break
  fi
  if [ "$attempt" -eq 12 ]; then
    echo "Unable to retrieve Nightscout secret after 12 attempts" >&2
    exit 1
  fi
  sleep 5
done
mongo_connection="$(jq -er '.MONGO_CONNECTION // .mongo_connection' <<<"$secret_json")"
api_secret="$(jq -er '.API_SECRET // .api_secret' <<<"$secret_json")"
unset secret_json

umask 077
{
  printf 'MONGO_CONNECTION=%s\n' "$mongo_connection"
  printf 'API_SECRET=%s\n' "$api_secret"
} > .env
unset mongo_connection api_secret
chown ubuntu:ubuntu .env

%{ if domain_name != "" ~}
cat > Caddyfile <<'EOF'
${domain_name} {
    reverse_proxy nightscout:1337
}
EOF
%{ else ~}
cat > Caddyfile <<'EOF'
:80 {
    reverse_proxy nightscout:1337
}
EOF
%{ endif ~}

cat > docker-compose.yml <<'EOF'
services:
  nightscout:
    image: nightscout/cgm-remote-monitor:latest
    restart: unless-stopped
    env_file: .env
    environment:
      TZ: Europe/London
      DISPLAY_UNITS: mmol
      ENABLE: careportal rawbg iob maker bridge cage sage ar2
    expose:
      - "1337"

  caddy:
    image: caddy:2
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - nightscout

volumes:
  caddy_data:
  caddy_config:
EOF

chown -R ubuntu:ubuntu /home/ubuntu/nightscout
docker compose pull
docker compose up -d
echo "Nightscout bootstrap complete."