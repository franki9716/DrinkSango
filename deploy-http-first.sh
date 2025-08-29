#!/bin/bash

# Script alternativo: Configurar SanguApp SIN SSL inicial
# Obtener SSL después de verificar DNS

set -e

MAIN_DOMAIN="toptraining.es"
N8N_SUBDOMAIN="n8n.toptraining.es"
VPS_IP="46.202.171.156"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo ""
    echo -e "${BLUE}🍹 $1${NC}"
    echo "============================================="
}

# Verificar root
if [ "$EUID" -ne 0 ]; then 
    print_error "Ejecutar como root: sudo $0"
    exit 1
fi

print_header "SanguApp + n8n - Configuración Sin SSL"

print_status "Configuración:"
echo "  🌐 SanguApp: $MAIN_DOMAIN"
echo "  🔧 n8n: $N8N_SUBDOMAIN"
echo "  🖥️  VPS IP: $VPS_IP"
echo ""

# Verificar DNS ANTES de continuar
print_status "🔍 Verificando DNS..."
DNS_CHECK=$(nslookup $MAIN_DOMAIN | grep -A 1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)

if [ "$DNS_CHECK" = "$VPS_IP" ]; then
    print_success "DNS configurado correctamente: $MAIN_DOMAIN → $VPS_IP"
else
    print_error "DNS NO configurado correctamente"
    echo "  Encontrado: $DNS_CHECK"
    echo "  Esperado: $VPS_IP"
    echo ""
    print_warning "DEBES configurar DNS ANTES de continuar:"
    echo "  1. Ve al Panel de Hostinger"
    echo "  2. Dominios → $MAIN_DOMAIN → Gestionar → DNS"
    echo "  3. Configura registro A: @ → $VPS_IP"
    echo "  4. Configura registro A: n8n → $VPS_IP"
    echo "  5. Espera 10-30 minutos para propagación"
    echo ""
    read -p "¿Quieres continuar sin SSL por ahora? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Solicitar datos
read -p "🔐 Password para base de datos SanguApp: " DB_PASSWORD
read -p "📧 Email para SSL (cuando esté listo): " EMAIL

# Detectar n8n actual
print_status "🔍 Detectando configuración actual de n8n..."
N8N_PORT=""
N8N_CONTAINER=""

if docker ps | grep -q n8n; then
    N8N_CONTAINER=$(docker ps --format "table {{.Names}}" | grep n8n | head -1)
    N8N_PORT=$(docker port $N8N_CONTAINER 2>/dev/null | grep "0.0.0.0:" | cut -d: -f2 | head -1)
    print_success "n8n en Docker: $N8N_CONTAINER, puerto: $N8N_PORT"
elif systemctl is-active --quiet n8n 2>/dev/null; then
    print_success "n8n como servicio systemd"
    N8N_PORT="5678"
elif ps aux | grep -v grep | grep -q n8n; then
    print_success "n8n ejecutándose como proceso"
    N8N_PORT="5678"
else
    print_warning "n8n no detectado automáticamente"
    read -p "¿En qué puerto está n8n? (5678): " USER_N8N_PORT
    N8N_PORT=${USER_N8N_PORT:-5678}
fi

print_success "Configuración detectada: n8n en puerto $N8N_PORT"

# Crear directorios
print_status "📁 Creando estructura de directorios..."
mkdir -p /opt/shared-proxy/{nginx,ssl}
mkdir -p /opt/sanguapp/{logs/{nginx,backend},backups,scripts}

# Configurar proxy HTTP (sin SSL por ahora)
print_status "🌐 Configurando proxy HTTP temporal..."
cat > /opt/shared-proxy/nginx/nginx.conf << 'NGINX_EOF'
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
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
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
        server 127.0.0.1:N8N_PORT_PLACEHOLDER;
    }
    
    upstream sanguapp_frontend {
        server 127.0.0.1:3010;
    }
    
    upstream sanguapp_api {
        server 127.0.0.1:3011;
    }
    
    # Main domain - SanguApp (HTTP por ahora)
    server {
        listen 80;
        server_name toptraining.es www.toptraining.es;
        
        # Permitir Let's Encrypt challenges
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        # SanguApp Frontend
        location / {
            proxy_pass http://sanguapp_frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # SanguApp API
        location /api/ {
            proxy_pass http://sanguapp_api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

    # n8n subdomain (HTTP por ahora)
    server {
        listen 80;
        server_name n8n.toptraining.es;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            proxy_pass http://n8n_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
NGINX_EOF

# Reemplazar puerto de n8n en la configuración
sed -i "s/N8N_PORT_PLACEHOLDER/$N8N_PORT/g" /opt/shared-proxy/nginx/nginx.conf

# Configurar SanguApp
print_status "🍹 Configurando SanguApp..."
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
CORS_ORIGIN=http://$MAIN_DOMAIN,https://$MAIN_DOMAIN,http://www.$MAIN_DOMAIN,https://www.$MAIN_DOMAIN
EOF

mkdir -p backend
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
CORS_ORIGIN=http://$MAIN_DOMAIN,https://$MAIN_DOMAIN,http://www.$MAIN_DOMAIN,https://www.$MAIN_DOMAIN
API_RATE_LIMIT=200
BCRYPT_ROUNDS=12
EOF

# Docker Compose para SanguApp
cat > docker-compose.internal.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: sanguapp_db_internal
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
    networks:
      - sanguapp_internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build: ./backend
    container_name: sanguapp_api_internal
    env_file: ./backend/.env
    ports:
      - "127.0.0.1:3011:3001"
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - sanguapp_internal
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    build:
      context: ./frontend
      args:
        REACT_APP_API_URL: http://toptraining.es/api
        REACT_APP_APP_NAME: "SanguApp TopTraining"
    container_name: sanguapp_web_internal
    ports:
      - "127.0.0.1:3010:80"
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
COMPOSE_EOF

# Docker Compose para proxy
cat > /opt/shared-proxy/docker-compose.yml << 'PROXY_COMPOSE_EOF'
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

# Crear script para configurar SSL después
cat > /opt/configure-ssl.sh << 'SSL_SCRIPT_EOF'
#!/bin/bash
# Script para configurar SSL después de verificar DNS

MAIN_DOMAIN="toptraining.es"
N8N_SUBDOMAIN="n8n.toptraining.es"
EMAIL="EMAIL_PLACEHOLDER"

echo "🔐 Configurando SSL para $MAIN_DOMAIN y $N8N_SUBDOMAIN..."

# Detener proxy temporalmente
docker stop toptraining_main_proxy 2>/dev/null || true

# Obtener certificados
certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL \
  -d $MAIN_DOMAIN -d www.$MAIN_DOMAIN -d $N8N_SUBDOMAIN

if [ $? -eq 0 ]; then
    # Copiar certificados
    mkdir -p /opt/shared-proxy/ssl
    cp /etc/letsencrypt/live/$MAIN_DOMAIN/fullchain.pem /opt/shared-proxy/ssl/${MAIN_DOMAIN}_fullchain.pem
    cp /etc/letsencrypt/live/$MAIN_DOMAIN/privkey.pem /opt/shared-proxy/ssl/${MAIN_DOMAIN}_privkey.pem
    cp /etc/letsencrypt/live/$N8N_SUBDOMAIN/fullchain.pem /opt/shared-proxy/ssl/${N8N_SUBDOMAIN}_fullchain.pem
    cp /etc/letsencrypt/live/$N8N_SUBDOMAIN/privkey.pem /opt/shared-proxy/ssl/${N8N_SUBDOMAIN}_privkey.pem
    chmod 644 /opt/shared-proxy/ssl/*.pem
    
    # Actualizar configuración nginx con HTTPS
    cat > /opt/shared-proxy/nginx/nginx.conf << 'NGINX_HTTPS_EOF'
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
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
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

    upstream n8n_backend {
        server 127.0.0.1:N8N_PORT_PLACEHOLDER;
    }
    
    upstream sanguapp_frontend {
        server 127.0.0.1:3010;
    }
    
    upstream sanguapp_api {
        server 127.0.0.1:3011;
    }
    
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name toptraining.es www.toptraining.es n8n.toptraining.es;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        location / {
            return 301 https://$server_name$request_uri;
        }
    }

    # Main domain - SanguApp HTTPS
    server {
        listen 443 ssl http2;
        server_name toptraining.es www.toptraining.es;
        
        ssl_certificate /etc/nginx/ssl/toptraining.es_fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/toptraining.es_privkey.pem;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers off;
        
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        location / {
            proxy_pass http://sanguapp_frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /api/ {
            proxy_pass http://sanguapp_api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

    # n8n subdomain HTTPS
    server {
        listen 443 ssl http2;
        server_name n8n.toptraining.es;
        
        ssl_certificate /etc/nginx/ssl/n8n.toptraining.es_fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/n8n.toptraining.es_privkey.pem;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers off;
        
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;

        location / {
            proxy_pass http://n8n_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
NGINX_HTTPS_EOF
    
    echo "✅ SSL configurado correctamente"
    echo "🔄 Reiniciando proxy con HTTPS..."
    cd /opt/shared-proxy && docker-compose up -d
    
else
    echo "❌ Error configurando SSL"
    echo "🔄 Reiniciando proxy HTTP..."
    cd /opt/shared-proxy && docker-compose up -d
fi
SSL_SCRIPT_EOF

# Reemplazar placeholders
sed -i "s/EMAIL_PLACEHOLDER/$EMAIL/g" /opt/configure-ssl.sh
sed -i "s/N8N_PORT_PLACEHOLDER/$N8N_PORT/g" /opt/configure-ssl.sh
chmod +x /opt/configure-ssl.sh

print_success "✅ Configuración HTTP completada"

echo ""
print_success "📋 PRÓXIMOS PASOS:"
echo ""
echo "1️⃣  Detener servicios actuales en puerto 80/443:"
if [ ! -z "$N8N_CONTAINER" ]; then
    echo "   docker stop $N8N_CONTAINER"
else
    echo "   systemctl stop nginx 2>/dev/null || true"
    echo "   # Detener manualmente n8n si es necesario"
fi

echo ""
echo "2️⃣  Iniciar proxy compartido:"
echo "   cd /opt/shared-proxy && docker-compose up -d"

echo ""
echo "3️⃣  Subir código SanguApp e iniciar:"
echo "   cd /opt/sanguapp"
echo "   # Asegúrate de tener los archivos frontend/ backend/ database/"
echo "   docker-compose -f docker-compose.internal.yml up -d --build"

echo ""
echo "4️⃣  Verificar funcionamiento HTTP:"
echo "   🌐 SanguApp: http://toptraining.es"
echo "   🔧 n8n: http://n8n.toptraining.es"

echo ""
echo "5️⃣  Configurar SSL cuando DNS esté propagado:"
echo "   /opt/configure-ssl.sh"

echo ""
print_warning "⚠️  IMPORTANTE: Debes subir el código de SanguApp antes del paso 3"
print_success "🍹 Configuración base completada!"
