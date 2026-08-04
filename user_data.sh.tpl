#!/bin/bash
set -e

# Install Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu

# Docker Compose plugin
apt-get update -y
apt-get install -y docker-compose-plugin

mkdir -p /home/ubuntu/nightscout
cd /home/ubuntu/nightscout

# Caddyfile — uses the domain passed in from Terraform, or falls back to
# serving plain HTTP on port 80 if no domain was set (edit later as needed)
%{ if domain_name != "" ~}
cat > Caddyfile <<EOF
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
    container_name: nightscout
    restart: always
    environment:
      MONGO_CONNECTION: "REPLACE_WITH_YOUR_ATLAS_CONNECTION_STRING"
      API_SECRET: "REPLACE_WITH_A_LONG_RANDOM_SECRET"
      TZ: "Europe/London"
      DISPLAY_UNITS: "mmol/L"
      ENABLE: "careportal rawbg iob maker bridge cage sage basal ar2"
    expose:
      - "1337"

  caddy:
    image: caddy:2
    container_name: caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - nightscout

volumes:
  caddy_data:
  caddy_config:
EOF

chown -R ubuntu:ubuntu /home/ubuntu/nightscout

echo "Nightscout files are in /home/ubuntu/nightscout" >> /home/ubuntu/SETUP_NOTES.txt
echo "Edit docker-compose.yml to set your real MONGO_CONNECTION and API_SECRET," >> /home/ubuntu/SETUP_NOTES.txt
echo "then run: cd nightscout && docker compose up -d" >> /home/ubuntu/SETUP_NOTES.txt
chown ubuntu:ubuntu /home/ubuntu/SETUP_NOTES.txt
