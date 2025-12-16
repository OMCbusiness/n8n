#!/bin/bash
# Script para instalar Docker, N8N, Redis y Nginx en AlmaLinux
# Crea el volumen externo n8n_data automáticamente

set -e

# Instalar dependencias
sudo dnf install -y yum-utils curl git
sudo dnf install epel-release dnf-plugins-core -y
sudo dnf install certbot -y

# Instalar Docker
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker

# Crear usuario para Docker (opcional)
sudo usermod -aG docker $USER

# Crear volumen externo n8n_data y volumen interno redis_data
docker volume create n8n_data
mkdir -p ~/redis_data

# Crear archivo docker-compose.yml EXACTAMENTE como lo proporcionaste
cat > ~/docker-compose.yml <<EOL
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
      - WEBHOOK_URL=https://n8n.ayudaskit.com/
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
    image: redis:6.2-alpine
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

# Levantar N8N y Redis
docker compose -f ~/docker-compose.yml up -d

# Instalar Nginx (solo instalación)
sudo dnf install -y nginx
sudo systemctl enable nginx
sudo setsebool -P nis_enabled 1

echo "✅ Instalación completa: N8N y Redis corriendo en Docker, Nginx instalado, y volumen externo n8n_data creado."
