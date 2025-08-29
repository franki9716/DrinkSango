#!/bin/bash

# SanguApp - Configuración para SUBDOMINIO sanguapp.toptraining.es
# Compatible con n8n existente en toptraining.es

set -e

echo "🍹 Desplegando SanguApp en sanguapp.toptraining.es"
echo "================================================="
echo "✅ Compatible con n8n existente en toptraining.es"

MAIN_DOMAIN="toptraining.es"
SUBDOMAIN="sanguapp.toptraining.es"
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

# Verificar root
if [ "$EUID" -ne 0 ]; then 
    print_error "Este script debe ejecutarse como root"
    exit 1
fi

print_status "Configuración:"
echo "  🌐 Dominio principal: $MAIN_DOMAIN (n8n existente)"
echo "  🍹 SanguApp: $SUBDOMAIN (nuevo)"
echo "  🖥️  IP VPS: $VPS_IP"
echo ""

# Solicitar datos
read -p "📧 Email para SSL: " EMAIL
read -p "🔐 Password para base de datos: " DB_PASSWORD
read -p "🔑 JWT Secret (Enter para generar): " JWT_SECRET

if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
    print_success "JWT Secret generado automáticamente"
fi

echo ""
print_warning "IMPORTANTE: Debes configurar DNS ANTES de continuar:"
echo "En tu panel Hostinger, agregar:"
echo "  Tipo: A"
echo "  Nombre: sanguapp"
echo "  Valor: $VPS_IP"
echo "  TTL: 300"
echo ""
read -p "¿Has configurado el DNS? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Configura el DNS primero y vuelve a ejecutar el script"
    exit 1
fi

print_status "🚀 Iniciando instalación..."

# Instalar dependencias si no existen
print_status "Verificando dependencias..."
if ! command -v docker &> /dev/null; then
    print_status "Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh && rm get-docker.sh
    systemctl start docker
    systemctl enable docker
fi

if ! command -v docker-compose &> /dev/null; then
    print_status "Instalando Docker Compose..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Crear estructura de directorios
print_status "Creando directorios..."
mkdir -p /opt/sanguapp/{logs/{nginx,backend},backups,nginx/ssl,scripts}

# Configurar SSL para el subdominio
print_status "Configurando SSL para $SUBDOMAIN..."
if ! command -v certbot &> /dev/null; then
    snap install core && snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
fi

# Obtener certificado SSL para el subdominio
certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL -d $SUBDOMAIN --http-01-port=8080

# Copiar certificados
cp /etc/letsencrypt/live/$SUBDOMAIN/fullchain.pem /opt/sanguapp/nginx/ssl/
cp /etc/letsencrypt/live/$SUBDOMAIN/privkey.pem /opt/sanguapp/nginx/ssl/
chmod 644 /opt/sanguapp/nginx/ssl/*.pem

# Configurar variables de entorno
cd /opt/sanguapp

cat > .env.production << EOF
NODE_ENV=production
DOMAIN=$SUBDOMAIN
VPS_IP=$VPS_IP

# Database
POSTGRES_DB=sanguapp_prod
POSTGRES_USER=sanguapp_prod
POSTGRES_PASSWORD=$DB_PASSWORD

# URLs
REACT_APP_API_URL=https://$SUBDOMAIN/api
REACT_APP_APP_NAME=SanguApp TopTraining
CORS_ORIGIN=https://$SUBDOMAIN

# Security
JWT_SECRET=$JWT_SECRET
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

JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=7d
CORS_ORIGIN=https://$SUBDOMAIN

API_RATE_LIMIT=200
BCRYPT_ROUNDS=12
EOF

# Crear nginx configuración para PUERTOS ALTERNATIVOS
cat > nginx/nginx.conf << 'NGINX_EOF'
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
                    '"$http_user_agent"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml+rss text/javascript;

    upstream backend {
        server backend:3001;
    }

    upstream frontend {
        server frontend:80;
    }
    
    # HTTP redirect
    server {
        listen 8080;
        server_name sanguapp.toptraining.es;
        return 301 https://$server_name$request_uri;
    }

    # HTTPS server en puerto alternativo
    server {
        listen 8443 ssl http2;
        server_name sanguapp.toptraining.es;
        
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers off;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;

        location / {
            proxy_pass http://frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /api/ {
            proxy_pass http://backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
NGINX_EOF

print_success "✅ Configuración completada para $SUBDOMAIN"
print_warning "📝 Siguiente paso: Sube el código de SanguApp y ejecuta:"
echo "   docker-compose -f docker-compose.subdomain.yml up -d --build"
echo ""
print_success "🌐 SanguApp estará en: https://$SUBDOMAIN:8443"
print_success "🔧 n8n seguirá en: https://$MAIN_DOMAIN"
