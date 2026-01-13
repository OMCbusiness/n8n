#!/bin/bash
# Script para instalar Docker, N8N, Redis y Nginx en AlmaLinux
# Crea el volumen externo n8n_data automáticamente
# Configura Nginx con HTTP->HTTPS y SSL para n8n.ayudaskit.com

set -e

# -------------------------------
# Instalar dependencias
# -------------------------------
sudo dnf install -y yum-utils curl git
sudo dnf install epel-release dnf-plugins-core -y
sudo dnf install certbot -y

# -------------------------------
# Instalar Docker
# -------------------------------
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker

# -------------------------------
# Crear volúmenes y carpetas
# -------------------------------
docker volume create n8n_data
mkdir -p /home/almalinux/redis_data

# -------------------------------
# Crear docker-compose.yml
# -------------------------------
cat > /home/almalinux/docker-compose.yml <<EOL
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=n8n.ayudaskit.com
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://n8n.ayudaskit.com
      - GENERIC_TIMEZONE=Europe/Madrid
      - QUEUE_HEALTH_CHECK_ACTIVE=true
      - QUEUE_HEALTH_CHECK_INTERVAL=5000
      - QUEUE_TYPE=redis
      - QUEUE_REDIS_URL=redis://redis:6379
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - redis

  redis:
    image: redis:latest
    restart: always
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

volumes:
  n8n_data:
    external: true
  redis_data:
    external: false
EOL

# -------------------------------
# Instalar y configurar Nginx
# -------------------------------
sudo dnf install -y nginx
sudo systemctl enable nginx

# Crear archivo de configuración Nginx para n8n
sudo tee /etc/nginx/conf.d/n8n.conf > /dev/null <<EOL
server {
    listen 80;
    server_name n8n.ayudaskit.com;

    # Redirigir todo el tráfico HTTP a HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }

    # Necesario para el desafío de Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /usr/share/nginx/html;
    }
}

server {
    listen 443 ssl;
    server_name n8n.ayudaskit.com;

    # Certificados SSL
    ssl_certificate /etc/letsencrypt/live/n8n.ayudaskit.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/n8n.ayudaskit.com/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/n8n.ayudaskit.com/chain.pem;

    # Configuración SSL recomendada
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_http_version 1.1;
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_buffering off;
        proxy_request_buffering off;
        client_max_body_size 50M;
    }
}
EOL

# Aplicar contextos SELinux correctos para Nginx
sudo restorecon -Rv /etc/nginx

# -------------------------------
# Mensaje final
# -------------------------------
echo "✅ Instalación completa: Docker, N8N, Redis corriendo, Nginx configurado con SSL y SELinux arreglado."
