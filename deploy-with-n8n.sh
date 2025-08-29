#!/bin/bash

# Solución DEFINITIVA: Configurar SanguApp CON n8n existente
# Usando un proxy reverso compartido

set -e

echo "🔧 Configurando SanguApp CON n8n existente"
echo "==========================================="

MAIN_DOMAIN="toptraining.es"
SANGUAPP_SUBDOMAIN="app.toptraining.es"
N8N_SUBDOMAIN="n8n.toptraining.es"
VPS_IP="46.202.171.156"

print_status() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

# Verificar root
if [ "$EUID" -ne 0 ]; then 
    print_error "Ejecutar como root: sudo $0"
    exit 1
fi

print_status "Plan de configuración:"
echo "  🌐 Dominio principal: $MAIN_DOMAIN → SanguApp (nueva config)"
echo "  🔧 n8n movido a: $N8N_SUBDOMAIN"
echo "  🍹 SanguApp en: $MAIN_DOMAIN"
echo ""

read -p "¿Quieres continuar con esta configuración? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Operación cancelada"
    exit 1
fi

# Solicitar datos
read -p "📧 Email para SSL: " EMAIL
read -p "🔐 Password para DB de SanguApp: " DB_PASSWORD

print_status "🔍 Analizando configuración actual de n8n..."

# Encontrar configuración actual de n8n
N8N_PORT=""
if docker ps | grep -q n8n; then
    N8N_CONTAINER=$(docker ps --format "table {{.Names}}" | grep n8n | head -1)
    N8N_PORT=$(docker port $N8N_CONTAINER 2>/dev/null | grep "0.0.0.0:" | cut -d: -f2 | head -1)
    print_success "n8n encontrado en contenedor: $N8N_CONTAINER, puerto: $N8N_PORT"
else
    print_status "n8n no encontrado en Docker, buscando en procesos..."
    N8N_PROCESS=$(ps aux | grep n8n | grep -v grep | head -1)
    if [ ! -z "$N8N_PROCESS" ]; then
        print_success "n8n ejecutándose como proceso"
        N8N_PORT="5678"  # Puerto por defecto de n8n
    else
        print_error "No se encontró n8n ejecutándose"
        exit 1
    fi
fi

print_status "🔧 Creando configuración de proxy compartido..."

# Crear directorio para el proxy
mkdir -p /opt/shared-proxy/{nginx,ssl}

# Configuración de Nginx como proxy maestro
cat > /opt/shared-proxy/nginx/nginx.conf << PROXY_EOF
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
    
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    client_max_body_size 50M;
    
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml+rss text/javascript;

    # Upstreams
    upstream n8n_backend {
        server 127.0.0.1:${N8N_PORT:-5678};
    }
    
    upstream sanguapp_frontend {
        server 127.0.0.1:3010;  # SanguApp frontend
    }
    
    upstream sanguapp_api {
        server 127.0.0.1:3011;  # SanguApp backend
    }
    
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $MAIN_DOMAIN www.$MAIN_DOMAIN $N8N_SUBDOMAIN;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        location / {
            return 301 https://\$server_name\$request_uri;
        }
    }

    # Main domain - SanguApp
    server {
        listen 443 ssl http2;
        server_name $MAIN_DOMAIN www.$MAIN_DOMAIN;
        
        ssl_certificate /etc/nginx/ssl/${MAIN_DOMAIN}_fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/${MAIN_DOMAIN}_privkey.pem;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers off;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # SanguApp Frontend
        location / {
            proxy_pass http://sanguapp_frontend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # SanguApp API
        location /api/ {
            proxy_pass http://sanguapp_api/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }

    # n8n subdomain
    server {
        listen 443 ssl http2;
        server_name $N8N_SUBDOMAIN;
        
        ssl_certificate /etc/nginx/ssl/${N8N_SUBDOMAIN}_fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/${N8N_SUBDOMAIN}_privkey.pem;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers off;
        
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;

        location / {
            proxy_pass http://n8n_backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # WebSocket support for n8n
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
PROXY_EOF

# Crear Docker Compose para el proxy maestro
cat > /opt/shared-proxy/docker-compose.yml << PROXY_COMPOSE_EOF
version: '3.8'

services:
  nginx-proxy:
    image: nginx:alpine
    container_name: toptraining_main_proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - /var/log/nginx:/var/log/nginx
      - /var/www/certbot:/var/www/certbot:ro
    restart: unless-stopped
    network_mode: "host"
PROXY_COMPOSE_EOF

print_status "🔐 Configurando certificados SSL..."

# Instalar certbot si no existe
if ! command -v certbot &> /dev/null; then
    snap install core && snap refresh core
    snap install --classic certbot
fi

# Detener servicios en puerto 80/443 temporalmente
print_status "⏹️ Deteniendo servicios temporalmente para SSL..."
systemctl stop nginx 2>/dev/null || true
docker stop $(docker ps -q --filter "publish=80" --filter "publish=443") 2>/dev/null || true

# Obtener certificados SSL
certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL \
  -d $MAIN_DOMAIN -d www.$MAIN_DOMAIN -d $N8N_SUBDOMAIN

# Copiar certificados
cp /etc/letsencrypt/live/$MAIN_DOMAIN/fullchain.pem /opt/shared-proxy/ssl/${MAIN_DOMAIN}_fullchain.pem
cp /etc/letsencrypt/live/$MAIN_DOMAIN/privkey.pem /opt/shared-proxy/ssl/${MAIN_DOMAIN}_privkey.pem
cp /etc/letsencrypt/live/$N8N_SUBDOMAIN/fullchain.pem /opt/shared-proxy/ssl/${N8N_SUBDOMAIN}_fullchain.pem
cp /etc/letsencrypt/live/$N8N_SUBDOMAIN/privkey.pem /opt/shared-proxy/ssl/${N8N_SUBDOMAIN}_privkey.pem
chmod 644 /opt/shared-proxy/ssl/*.pem

print_status "🍹 Configurando SanguApp en puertos internos..."

# Configurar SanguApp con puertos internos
mkdir -p /opt/sanguapp
cd /opt/sanguapp

cat > .env.production << SANGUAPP_ENV_EOF
NODE_ENV=production
DOMAIN=$MAIN_DOMAIN
POSTGRES_DB=sanguapp_prod
POSTGRES_USER=sanguapp_prod
POSTGRES_PASSWORD=$DB_PASSWORD
REACT_APP_API_URL=https://$MAIN_DOMAIN/api
REACT_APP_APP_NAME=SanguApp TopTraining
JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
CORS_ORIGIN=https://$MAIN_DOMAIN,https://www.$MAIN_DOMAIN
SANGUAPP_ENV_EOF

# Docker Compose para SanguApp (puertos internos)
cat > docker-compose.internal.yml << SANGUAPP_COMPOSE_EOF
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: sanguapp_db_internal
    environment:
      POSTGRES_DB: \${POSTGRES_DB}
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    ports:
      - "127.0.0.1:5434:5432"
    restart: unless-stopped
    networks:
      - sanguapp_internal

  backend:
    build: ./backend
    container_name: sanguapp_api_internal
    env_file: .env.production
    ports:
      - "127.0.0.1:3011:3001"  # Puerto interno para el proxy
    depends_on:
      - postgres
    restart: unless-stopped
    networks:
      - sanguapp_internal

  frontend:
    build:
      context: ./frontend
      args:
        REACT_APP_API_URL: https://$MAIN_DOMAIN/api
    container_name: sanguapp_web_internal
    ports:
      - "127.0.0.1:3010:80"   # Puerto interno para el proxy
    depends_on:
      - backend
    restart: unless-stopped
    networks:
      - sanguapp_internal

volumes:
  postgres_data:

networks:
  sanguapp_internal:
    driver: bridge
SANGUAPP_COMPOSE_EOF

print_success "✅ Configuración completada"

echo ""
print_success "🎯 Configuración final:"
echo "  🌐 $MAIN_DOMAIN → SanguApp (puertos internos 3010/3011)"
echo "  🔧 $N8N_SUBDOMAIN → n8n (puerto $N8N_PORT)"
echo "  🔒 Proxy maestro → puertos 80/443"
echo ""

print_success "📝 Próximos pasos:"
echo "1. Configura DNS en Hostinger:"
echo "   A | n8n | $VPS_IP"
echo ""
echo "2. Inicia el proxy maestro:"
echo "   cd /opt/shared-proxy && docker-compose up -d"
echo ""
echo "3. Sube código SanguApp y ejecuta:"
echo "   cd /opt/sanguapp && docker-compose -f docker-compose.internal.yml up -d --build"
echo ""

print_success "🔗 URLs finales:"
echo "  🍹 SanguApp: https://$MAIN_DOMAIN"
echo "  🔧 n8n: https://$N8N_SUBDOMAIN"
