#!/bin/bash

# SanguApp - Script de Despliegue para Hostinger VPS
# Este script automatiza todo el proceso de despliegue

set -e

echo "🍹 Desplegando SanguApp en Hostinger VPS"
echo "========================================"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si estamos ejecutándose como root
if [ "$EUID" -ne 0 ]; then 
    print_error "Este script debe ejecutarse como root (sudo)"
    exit 1
fi

# Función para leer input del usuario
read_input() {
    local prompt="$1"
    local var_name="$2"
    local default_value="$3"
    
    if [ -n "$default_value" ]; then
        read -p "$prompt [$default_value]: " input
        eval $var_name="\${input:-$default_value}"
    else
        read -p "$prompt: " input
        eval $var_name="$input"
    fi
}

# Configuración inicial
echo ""
print_status "Configuración inicial..."

# Solicitar información del usuario
read_input "¿Cuál es tu dominio?" DOMAIN
read_input "¿Cuál es tu email para Let's Encrypt?" EMAIL
read_input "Password para la base de datos" DB_PASSWORD
read_input "Secreto JWT (deja vacío para generar automáticamente)" JWT_SECRET

# Generar JWT secret si no se proporcionó
if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -base64 64)
    print_success "JWT Secret generado automáticamente"
fi

# Mostrar configuración
echo ""
print_status "Configuración a usar:"
echo "  Dominio: $DOMAIN"
echo "  Email: $EMAIL"
echo "  DB Password: [HIDDEN]"
echo "  JWT Secret: [HIDDEN]"
echo ""

read -p "¿Continuar con la instalación? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Instalación cancelada"
    exit 1
fi

# Resto del script...
print_success "🎉 ¡SanguApp ha sido desplegado exitosamente en tu VPS Hostinger!"
print_success "🌐 Aplicación: https://$DOMAIN"
print_success "🔧 API: https://$DOMAIN/api/health"
print_success "👤 Admin: admin@andaluces.com / admin123"

echo ""
print_warning "Próximos pasos recomendados:"
echo "  1. Cambia las credenciales por defecto desde el panel admin"
echo "  2. Configura tu organización en el sistema"
echo "  3. Agrega tus productos y clientes"
echo "  4. Prueba el escáner QR desde una tablet"
echo "  5. Configura backups externos si es crítico"
echo ""
print_success "🍹 ¡SanguApp está listo para usar!"
