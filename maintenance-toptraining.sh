#!/bin/bash

# SanguApp TopTraining - Scripts de Mantenimiento
# Dominio: toptraining.es | IP: 46.202.171.156

DOMAIN="toptraining.es"
PROJECT_DIR="/opt/sanguapp"
COMPOSE_FILE="docker-compose.toptraining.yml"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}🍹 SanguApp TopTraining - $1${NC}"
    echo "============================================="
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Función para mostrar el menú
show_menu() {
    echo -e "\n${YELLOW}¿Qué operación quieres realizar?${NC}"
    echo "1. 📊 Ver estado de servicios"
    echo "2. 🔍 Ver logs en tiempo real"
    echo "3. 🔄 Reiniciar servicios"
    echo "4. ⬇️  Detener servicios"
    echo "5. ⬆️  Iniciar servicios"
    echo "6. 🏗️  Reconstruir y actualizar"
    echo "7. 💾 Crear backup"
    echo "8. 📈 Ver estadísticas de uso"
    echo "9. 🧹 Limpiar sistema"
    echo "10. 🔐 Renovar certificado SSL"
    echo "11. 📱 Probar conectividad"
    echo "12. ❌ Salir"
    echo ""
}

# Función para verificar estado
check_status() {
    print_header "Estado de Servicios"
    
    cd $PROJECT_DIR
    echo "📊 Estado de contenedores:"
    docker-compose -f $COMPOSE_FILE ps
    
    echo -e "\n🌐 Conectividad externa:"
    if curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN/health | grep -q "200"; then
        print_success "Frontend accesible (https://$DOMAIN)"
    else
        print_error "Frontend no accesible"
    fi
    
    if curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN/api/health | grep -q "200"; then
        print_success "API Backend accesible (https://$DOMAIN/api)"
    else
        print_error "API Backend no accesible"
    fi
}

# Función principal
main() {
    print_header "Sistema de Mantenimiento"
    echo "📍 Dominio: https://$DOMAIN"
    echo "📁 Directorio: $PROJECT_DIR"
    echo ""
    
    while true; do
        show_menu
        read -p "Selecciona una opción (1-12): " choice
        
        case $choice in
            1) check_status ;;
            2) 
                cd $PROJECT_DIR
                docker-compose -f $COMPOSE_FILE logs -f --tail=100
                ;;
            3) 
                cd $PROJECT_DIR
                docker-compose -f $COMPOSE_FILE restart
                print_success "Servicios reiniciados"
                ;;
            4)
                cd $PROJECT_DIR
                docker-compose -f $COMPOSE_FILE down
                print_success "Servicios detenidos"
                ;;
            5)
                cd $PROJECT_DIR
                docker-compose -f $COMPOSE_FILE up -d
                print_success "Servicios iniciados"
                ;;
            6)
                print_header "Actualizando SanguApp"
                cd $PROJECT_DIR
                git pull origin main
                docker-compose -f $COMPOSE_FILE build --no-cache
                docker-compose -f $COMPOSE_FILE up -d
                print_success "Actualización completada"
                ;;
            7)
                print_header "Creando Backup"
                DATE=$(date +%Y%m%d_%H%M%S)
                docker exec sanguapp_db_toptraining pg_dump -U sanguapp_prod sanguapp_prod > "/opt/sanguapp/backups/backup_$DATE.sql"
                gzip "/opt/sanguapp/backups/backup_$DATE.sql"
                print_success "Backup creado: backup_$DATE.sql.gz"
                ;;
            12)
                print_success "¡Hasta luego!"
                exit 0
                ;;
            *)
                print_error "Opción no válida"
                ;;
        esac
        
        echo ""
        read -p "Presiona Enter para continuar..."
    done
}

# Verificar permisos root
if [ "$EUID" -ne 0 ]; then 
    print_error "Este script debe ejecutarse como root"
    exit 1
fi

main
