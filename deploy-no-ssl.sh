#!/bin/bash

# Script TEMPORAL: SanguApp funcionando SIN SSL
# Para resolver problemas de CAA/SSL después

set -e

MAIN_DOMAIN="toptraining.es"
N8N_SUBDOMAIN="n8n.toptraining.es"
VPS_IP="46.202.171.156"

print_status() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
print_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

if [ "$EUID" -ne 0 ]; then 
    print_error "Ejecutar como root: sudo $0"
    exit 1
fi

echo "🍹 SanguApp TEMPORAL - Sin SSL"
echo "=============================="
echo ""

print_warning "Este script configura SanguApp sin SSL por problemas de CAA"
print_status "URLs temporales:"
echo "  🌐 SanguApp: http://$MAIN_DOMAIN"
echo "  🔧 n8n: http://$N8N_SUBDOMAIN"
echo ""

read -p "🔐 Password para base de datos: " DB_PASSWORD

# Detectar n8n
N8N_PORT=""
if docker ps | grep -q n8n; then
    N8N_CONTAINER=$(docker ps --format "table {{.Names}}" | grep n8n | head -1)
    N8N_PORT=$(docker port $N8N_CONTAINER 2>/dev/null | grep ":5678" | cut -d: -f2 | head -1)
    print_success "n8n detectado: $N8N_CONTAINER, puerto: $N8N_PORT"
elif systemctl is-active --quiet n8n 2>/dev/null; then
    N8N_PORT="5678"
    print_success "n8n como servicio systemd"
else
    N8N_PORT="5678"
    print_warning "n8n no detectado, usando puerto por defecto: 5678"
fi

# Crear directorios
mkdir -p /opt/shared-proxy/nginx
mkdir -p /opt/sanguapp/{backend,logs/{nginx,backend},backups}

# Configurar proxy HTTP simple
cat > /opt/shared-proxy/nginx/nginx.conf << NGINX_EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    sendfile on;
    keepalive_timeout 65;
    client_max_body_size 50M;
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml+rss text/javascript;

    upstream n8n_backend {
        server 127.0.0.1:$N8N_PORT;
    }
    
    upstream sanguapp_frontend {
        server 127.0.0.1:3010;
    }
    
    upstream sanguapp_api {
        server 127.0.0.1:3011;
    }
    
    # Main domain - SanguApp
    server {
        listen 80;
        server_name $MAIN_DOMAIN www.$MAIN_DOMAIN;

        location / {
            proxy_pass http://sanguapp_frontend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }

        location /api/ {
            proxy_pass http://sanguapp_api/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }

    # n8n subdomain
    server {
        listen 80;
        server_name $N8N_SUBDOMAIN;

        location / {
            proxy_pass http://n8n_backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
NGINX_EOF

# Docker compose para proxy
cat > /opt/shared-proxy/docker-compose.yml << 'PROXY_COMPOSE_EOF'
version: '3.8'

services:
  nginx-proxy:
    image: nginx:alpine
    container_name: toptraining_http_proxy
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - /var/log/nginx:/var/log/nginx
    restart: unless-stopped
    network_mode: "host"
PROXY_COMPOSE_EOF

# Configurar SanguApp
cd /opt/sanguapp

cat > .env.production << EOF
NODE_ENV=production
DOMAIN=$MAIN_DOMAIN
POSTGRES_DB=sanguapp_prod
POSTGRES_USER=sanguapp_prod
POSTGRES_PASSWORD=$DB_PASSWORD
REACT_APP_API_URL=http://$MAIN_DOMAIN/api
REACT_APP_APP_NAME=SanguApp TopTraining
JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
CORS_ORIGIN=http://$MAIN_DOMAIN,http://www.$MAIN_DOMAIN
EOF

cat > backend/.env << EOF
NODE_ENV=production
PORT=3001
DB_HOST=postgres
DB_PORT=5432
DB_NAME=sanguapp_prod
DB_USER=sanguapp_prod
DB_PASSWORD=$DB_PASSWORD
JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
JWT_EXPIRES_IN=7d
CORS_ORIGIN=http://$MAIN_DOMAIN,http://www.$MAIN_DOMAIN
API_RATE_LIMIT=200
BCRYPT_ROUNDS=12
EOF

# Docker compose para SanguApp
cat > docker-compose.http.yml << 'SANGUAPP_COMPOSE_EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: sanguapp_db_http
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    ports:
      - "127.0.0.1:5434:5432"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build: ./backend
    container_name: sanguapp_api_http
    env_file: ./backend/.env
    ports:
      - "127.0.0.1:3011:3001"
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    build:
      context: ./frontend
      args:
        REACT_APP_API_URL: http://$MAIN_DOMAIN/api
        REACT_APP_APP_NAME: "SanguApp TopTraining"
    container_name: sanguapp_web_http
    ports:
      - "127.0.0.1:3010:80"
    depends_on:
      - backend
    restart: unless-stopped

volumes:
  postgres_data:
SANGUAPP_COMPOSE_EOF

print_success "✅ Configuración HTTP completada"

echo ""
print_warning "🚀 PASOS PARA ACTIVAR:"
echo ""
echo "1️⃣  Detener servicios actuales:"
echo "   # Detener n8n Docker si existe:"
if [ ! -z "$N8N_CONTAINER" ]; then
    echo "   docker stop $N8N_CONTAINER"
fi
echo "   # Detener nginx si existe:"
echo "   systemctl stop nginx 2>/dev/null || true"

echo ""
echo "2️⃣  Iniciar proxy HTTP:"
echo "   cd /opt/shared-proxy"
echo "   docker-compose up -d"

echo ""
echo "3️⃣  Iniciar SanguApp (después de subir código):"
echo "   cd /opt/sanguapp"
echo "   docker-compose -f docker-compose.http.yml up -d --build"

echo ""
print_success "📱 URLs (SIN SSL):"
echo "   🌐 SanguApp: http://$MAIN_DOMAIN"
echo "   🔧 n8n: http://$N8N_SUBDOMAIN"

echo ""
print_warning "⚠️  Para SSL después de resolver CAA:"
echo "   1. Eliminar registros CAA en Hostinger DNS"
echo "   2. Ejecutar: certbot certonly --webroot -w /var/www/certbot -d $MAIN_DOMAIN -d www.$MAIN_DOMAIN -d $N8N_SUBDOMAIN"
echo "   3. Actualizar nginx.conf con configuración HTTPS"
