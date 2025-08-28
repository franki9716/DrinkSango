#!/bin/bash

# SanguApp Development Setup Script
# Este script configura el entorno de desarrollo completo

set -e

echo "🍹 Configurando SanguApp - Entorno de Desarrollo"
echo "================================================"

# Verificar dependencias
echo "📋 Verificando dependencias del sistema..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado. Por favor, instala Docker primero."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose no está instalado. Por favor, instala Docker Compose primero."
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "❌ Node.js no está instalado. Por favor, instala Node.js 18+ primero."
    exit 1
fi

echo "✅ Dependencias verificadas"

# Crear archivo .env para backend si no existe
if [ ! -f "backend/.env" ]; then
    echo "📄 Creando archivo .env para el backend..."
    cp backend/.env.example backend/.env
    echo "✅ Archivo .env creado. Puedes modificarlo si necesitas configuraciones específicas."
fi

# Función para mostrar opciones
show_menu() {
    echo ""
    echo "🚀 ¿Cómo quieres ejecutar SanguApp?"
    echo "1. 🐳 Con Docker (Recomendado para producción)"
    echo "2. 💻 En modo desarrollo (Backend y Frontend por separado)"
    echo "3. 📊 Solo base de datos con Docker + desarrollo local"
    echo "4. 🧹 Limpiar contenedores y empezar desde cero"
    echo "5. 📋 Ver logs de los servicios"
    echo "6. ❌ Salir"
    echo ""
}

# Función para ejecutar con Docker
run_docker() {
    echo "🐳 Iniciando SanguApp con Docker..."
    
    # Build y start de todos los servicios
    docker-compose up --build -d
    
    echo ""
    echo "✅ SanguApp está ejecutándose!"
    echo "🌐 Frontend: http://localhost:3000"
    echo "🔧 Backend API: http://localhost:3001"
    echo "🗄️ Base de datos: localhost:5432"
    echo "📊 PgAdmin: http://localhost:5050 (admin@sanguapp.com / admin2024)"
    echo ""
    echo "Para ver los logs: docker-compose logs -f"
    echo "Para detener: docker-compose down"
}

# Función para desarrollo local
run_development() {
    echo "💻 Configurando entorno de desarrollo..."
    
    # Solo levantar base de datos con Docker
    echo "🗄️ Iniciando base de datos..."
    docker-compose up -d postgres
    
    # Esperar a que la base de datos esté lista
    echo "⏳ Esperando a que la base de datos esté lista..."
    sleep 10
    
    # Instalar dependencias del backend
    echo "📦 Instalando dependencias del backend..."
    cd backend && npm install
    
    # Instalar dependencias del frontend
    echo "📦 Instalando dependencias del frontend..."
    cd ../frontend && npm install
    cd ..
    
    echo ""
    echo "✅ Entorno de desarrollo configurado!"
    echo ""
    echo "🔧 Para iniciar el backend:"
    echo "   cd backend && npm run dev"
    echo ""
    echo "🌐 Para iniciar el frontend:"
    echo "   cd frontend && npm start"
    echo ""
    echo "🗄️ Base de datos ejecutándose en: localhost:5432"
}

# Función para desarrollo híbrido
run_hybrid() {
    echo "📊 Iniciando base de datos y servicios auxiliares..."
    
    docker-compose up -d postgres pgadmin
    
    echo "✅ Servicios auxiliares iniciados!"
    echo "🗄️ Base de datos: localhost:5432"
    echo "📊 PgAdmin: http://localhost:5050"
    echo ""
    echo "Ahora puedes ejecutar backend y frontend en modo desarrollo."
}

# Función para limpiar
clean_all() {
    echo "🧹 Limpiando contenedores y volúmenes..."
    
    docker-compose down -v
    docker system prune -f
    
    echo "✅ Limpieza completada!"
}

# Función para ver logs
show_logs() {
    echo "📋 Mostrando logs de los servicios..."
    docker-compose logs -f --tail=50
}

# Menú principal
while true; do
    show_menu
    read -p "Selecciona una opción (1-6): " choice
    
    case $choice in
        1)
            run_docker
            break
            ;;
        2)
            run_development
            break
            ;;
        3)
            run_hybrid
            break
            ;;
        4)
            clean_all
            ;;
        5)
            show_logs
            break
            ;;
        6)
            echo "👋 ¡Hasta luego!"
            exit 0
            ;;
        *)
            echo "❌ Opción no válida. Por favor, selecciona 1-6."
            ;;
    esac
done

echo ""
echo "🎉 ¡SanguApp está listo para usar!"
echo ""
echo "📚 Documentación adicional:"
echo "   - README.md: Guía completa del proyecto"
echo "   - docs/: Documentación técnica"
echo ""
echo "🆘 ¿Necesitas ayuda?"
echo "   - GitHub Issues: Reporta problemas"
echo "   - Email: soporte@sanguapp.com"
echo ""
echo "¡Que disfrutes usando SanguApp! 🍹"
