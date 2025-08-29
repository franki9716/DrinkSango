#!/bin/bash

# SanguApp - Configuración específica para toptraining.es
# VPS IP: 46.202.171.156

set -e

echo "🍹 Desplegando SanguApp en toptraining.es"
echo "========================================="

# Configuración fija para tu dominio
DOMAIN="toptraining.es"
VPS_IP="46.202.171.156"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Verificar si estamos ejecutándose como root
if [ "$EUID" -ne 0 ]; then 
    print_error "Este script debe ejecutarse como root"
    print_status "Ejecuta: sudo ./deploy-toptraining.sh"
    exit 1
fi

print_status "Configuración para toptraining.es:"
echo "  🌐 Dominio: $DOMAIN"
echo "  🖥️  IP VPS: $VPS_IP"
echo ""

# Solicitar datos necesarios
read -p "📧 Email para certificados SSL: " EMAIL
read -p "🔐 Password para base de datos: " DB_PASSWORD
read -p "🔑 JWT Secret (Enter para generar automáticamente): " JWT_SECRET

# Generar JWT secret si no se proporcionó
if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
    print_success "JWT Secret generado automáticamente"
fi

echo ""
read -p "¿Continuar con la instalación? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Instalación cancelada"
    exit 1
fi

print_status "🚀 Iniciando instalación completa..."

# 1. Actualizar sistema
print_status "Actualizando el sistema..."
apt update && apt upgrade -y
apt install -y curl wget git unzip htop nano ufw fail2ban software-properties-common

# 2. Configurar zona horaria
print_status "Configurando zona horaria..."
timedatectl set-timezone Europe/Madrid

# 3. Configurar Firewall
print_status "Configurando firewall UFW..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw --force enable

# 4. Instalar Docker
print_status "Instalando Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl start docker
    systemctl enable docker
    usermod -aG docker root
    rm get-docker.sh
    print_success "Docker instalado"
else
    print_success "Docker ya instalado"
fi

# 5. Instalar Docker Compose
print_status "Instalando Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    print_success "Docker Compose instalado"
else
    print_success "Docker Compose ya instalado"
fi

# 6. Crear estructura de directorios
print_status "Creando estructura de directorios..."
mkdir -p /opt/sanguapp/{logs/{nginx,backend},backups,nginx/ssl,scripts}

# 7. Configurar SSL con Let's Encrypt
print_status "Instalando Certbot para SSL..."
if ! command -v certbot &> /dev/null; then
    snap install core
    snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
fi

print_status "Obteniendo certificado SSL para $DOMAIN..."
certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL -d $DOMAIN -d www.$DOMAIN

# Copiar certificados para Docker
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /opt/sanguapp/nginx/ssl/
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /opt/sanguapp/nginx/ssl/
chmod 644 /opt/sanguapp/nginx/ssl/*.pem

# 8. Navegar al directorio del proyecto
cd /opt/sanguapp

# 9. Crear variables de entorno
print_status "Configurando variables de entorno..."

# Archivo principal de entorno
cat > .env.production << EOF
# Configuración de producción para toptraining.es
NODE_ENV=production
DOMAIN=$DOMAIN
VPS_IP=$VPS_IP

# Database
POSTGRES_DB=sanguapp_prod
POSTGRES_USER=sanguapp_prod  
POSTGRES_PASSWORD=$DB_PASSWORD

# API URLs
REACT_APP_API_URL=https://$DOMAIN/api
REACT_APP_APP_NAME=SanguApp TopTraining
REACT_APP_VERSION=1.0.0

# Security
JWT_SECRET=$JWT_SECRET
CORS_ORIGIN=https://$DOMAIN,https://www.$DOMAIN
EOF

# Backend environment
mkdir -p backend
cat > backend/.env << EOF
NODE_ENV=production
PORT=3001

# Database
DB_HOST=postgres
DB_PORT=5432
DB_NAME=sanguapp_prod
DB_USER=sanguapp_prod
DB_PASSWORD=$DB_PASSWORD

# JWT
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=7d

# CORS
CORS_ORIGIN=https://$DOMAIN,https://www.$DOMAIN

# Security
API_RATE_LIMIT=200
BCRYPT_ROUNDS=12

# Upload limits
MAX_FILE_SIZE=5MB
UPLOAD_PATH=/app/uploads
EOF

# 10. Configurar nginx específico
print_status "Configurando Nginx..."
cat > nginx/nginx.conf << 'NGINX_EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';
    
    access_log /var/log/nginx/access.log main;
    
    # Performance settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 50M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    # Buffer sizes
    client_body_buffer_size 128k;
    client_header_buffer_size 3m;
    large_client_header_buffers 4 256k;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-Robots-Tag "noindex, nofollow" always;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

    # Upstream servers
    upstream backend {
        server backend:3001 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    upstream frontend {
        server frontend:80 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }
    
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name toptraining.es www.toptraining.es;
        
        # Let's Encrypt challenge
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        # Redirect all other traffic to HTTPS
        location / {
            return 301 https://$server_name$request_uri;
        }
    }

    # Main HTTPS server
    server {
        listen 443 ssl http2;
        server_name toptraining.es www.toptraining.es;
        
        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        
        # Modern SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 1d;
        ssl_session_tickets off;
        
        # OCSP stapling
        ssl_stapling on;
        ssl_stapling_verify on;
        
        # HSTS
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
        
        # Security headers específicos
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; media-src 'self'; object-src 'none'; child-src 'self'; worker-src 'self'; frame-ancestors 'none';" always;

        # Root location - Frontend
        location / {
            proxy_pass http://frontend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # Error pages
            error_page 502 503 504 /50x.html;
        }

        # API Backend con rate limiting
        location /api/ {
            # Rate limiting
            limit_req zone=api burst=20 nodelay;
            
            proxy_pass http://backend/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            
            # API Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
        
        # Login endpoint con rate limiting estricto
        location /api/auth/login {
            limit_req zone=login burst=5 nodelay;
            
            proxy_pass http://backend/auth/login;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # Static assets con caché largo
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            proxy_pass http://frontend;
            expires 1y;
            add_header Cache-Control "public, immutable";
            add_header Vary Accept-Encoding;
            
            # Compresión específica para assets
            gzip_static on;
        }
        
        # Health checks
        location /health {
            access_log off;
            return 200 "SanguApp TopTraining OK\n";
            add_header Content-Type text/plain;
        }
        
        location /api/health {
            proxy_pass http://backend/health;
            access_log off;
        }
        
        # Block access to sensitive files
        location ~ /\.(htaccess|htpasswd|env|git) {
            deny all;
            access_log off;
            log_not_found off;
        }
        
        location ~* \.(sql|log|conf|bak|backup)$ {
            deny all;
            access_log off;
            log_not_found off;
        }
    }
}
NGINX_EOF

print_success "Configuración completada para toptraining.es"

# 11. Mensaje final
echo ""
print_success "🎉 SanguApp configurado para toptraining.es"
echo ""
print_warning "Próximos pasos:"
echo "1. 📁 Sube el código de SanguApp a /opt/sanguapp"
echo "2. 🐳 Ejecuta: docker-compose up -d --build"
echo "3. 🌐 Accede a: https://toptraining.es"
echo ""
print_status "Archivos de configuración creados:"
echo "  📄 /opt/sanguapp/.env.production"
echo "  📄 /opt/sanguapp/backend/.env"  
echo "  📄 /opt/sanguapp/nginx/nginx.conf"
echo "  🔐 Certificados SSL configurados"
echo ""
print_success "🍹 ¡Listo para desplegar SanguApp!"
