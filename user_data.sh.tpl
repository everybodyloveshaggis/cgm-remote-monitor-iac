#!/bin/bash

set -euo pipefail

exec > >(tee /var/log/nightscout-user-data.log | logger -t nightscout-user-data -s 2>/dev/console) 2>&1

echo "Starting Nightscout bootstrap..."

# ---------------------------------------------------------
# System update
# ---------------------------------------------------------

apt-get update -y
apt-get upgrade -y

# ---------------------------------------------------------
# Install Docker
# ---------------------------------------------------------

curl -fsSL https://get.docker.com | sh

systemctl enable docker
systemctl start docker

usermod -aG docker ubuntu

# ---------------------------------------------------------
# Docker Compose
# ---------------------------------------------------------

apt-get install -y docker-compose-plugin

# ---------------------------------------------------------
# Nightscout directory
# ---------------------------------------------------------

mkdir -p /home/ubuntu/nightscout

cd /home/ubuntu/nightscout

# ---------------------------------------------------------
# Caddy
# ---------------------------------------------------------

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

# ---------------------------------------------------------
# Docker Compose
# ---------------------------------------------------------

cat > docker-compose.yml <<'EOF'
services:

  nightscout:
    image: nightscout/cgm-remote-monitor:latest
    container_name: nightscout

    restart: unless-stopped

    environment:
      MONGO_CONNECTION: "REPLACE_WITH_YOUR_ATLAS_CONNECTION_STRING"
      API_SECRET: "REPLACE_WITH_A_LONG_RANDOM_SECRET"

      TZ: "Europe/London"
      DISPLAY_UNITS: "mmol"

      ENABLE: "careportal rawbg iob maker bridge cage sage ar2"

    expose:
      - "1337"

  caddy:
    image: caddy:2
    container_name: caddy

    restart: unless-stopped

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

# ---------------------------------------------------------
# Permissions
# ---------------------------------------------------------

chown -R ubuntu:ubuntu /home/ubuntu/nightscout

# ---------------------------------------------------------
# Start Nightscout
# ---------------------------------------------------------

cd /home/ubuntu/nightscout

docker compose pull

docker compose up -d

# ---------------------------------------------------------
# Setup notes
# ---------------------------------------------------------

cat > /home/ubuntu/SETUP_NOTES.txt <<'EOF'
Nightscout is installed in:

/home/ubuntu/nightscout

Useful commands:

cd /home/ubuntu/nightscout

docker compose ps

docker compose logs -f

docker compose restart

docker compose pull
docker compose up -d

User-data log:

/var/log/nightscout-user-data.log

Remember to replace:

MONGO_CONNECTION
API_SECRET

in docker-compose.yml if they have not already been configured.
EOF

chown ubuntu:ubuntu /home/ubuntu/SETUP_NOTES.txt

echo "Nightscout bootstrap complete."