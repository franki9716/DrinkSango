@echo off
title SanguApp - Setup para Windows
color 0A

echo.
echo     🍹 SanguApp - Setup para Windows
echo ==========================================
echo.

:: Verificar dependencias
echo 📋 Verificando dependencias del sistema...

where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Docker no está instalado. Por favor, instala Docker Desktop primero.
    echo    Descarga desde: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

where docker-compose >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Docker Compose no está instalado. Generalmente viene con Docker Desktop.
    pause
    exit /b 1
)

where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Node.js no está instalado. Por favor, instala Node.js 18+ primero.
    echo    Descarga desde: https://nodejs.org
    pause
    exit /b 1
)

echo ✅ Dependencias verificadas
echo.

:: Crear archivo .env para backend si no existe
if not exist "backend\.env" (
    echo 📄 Creando archivo .env para el backend...
    copy "backend\.env.example" "backend\.env" >nul
    echo ✅ Archivo .env creado.
)

:menu
echo.
echo 🚀 ¿Cómo quieres ejecutar SanguApp?
echo 1. 🐳 Con Docker (Recomendado para producción)
echo 2. 💻 En modo desarrollo (Backend y Frontend por separado)
echo 3. 📊 Solo base de datos con Docker + desarrollo local
echo 4. 🧹 Limpiar contenedores y empezar desde cero
echo 5. 📋 Ver logs de los servicios
echo 6. ❌ Salir
echo.

set /p choice="Selecciona una opción (1-6): "

if "%choice%"=="1" goto docker_run
if "%choice%"=="2" goto dev_run
if "%choice%"=="3" goto hybrid_run
if "%choice%"=="4" goto clean_all
if "%choice%"=="5" goto show_logs
if "%choice%"=="6" goto exit
echo ❌ Opción no válida. Por favor, selecciona 1-6.
goto menu

:docker_run
echo.
echo 🐳 Iniciando SanguApp con Docker...
docker-compose up --build -d

echo.
echo ✅ SanguApp está ejecutándose!
echo 🌐 Frontend: http://localhost:3000
echo 🔧 Backend API: http://localhost:3001
echo 🗄️ Base de datos: localhost:5432
echo 📊 PgAdmin: http://localhost:5050 (admin@sanguapp.com / admin2024)
echo.
echo Para ver los logs: docker-compose logs -f
echo Para detener: docker-compose down
goto end

:dev_run
echo.
echo 💻 Configurando entorno de desarrollo...

echo 🗄️ Iniciando base de datos...
docker-compose up -d postgres

echo ⏳ Esperando a que la base de datos esté lista...
timeout /t 10 /nobreak >nul

echo 📦 Instalando dependencias del backend...
cd backend && npm install
cd ..

echo 📦 Instalando dependencias del frontend...
cd frontend && npm install
cd ..

echo.
echo ✅ Entorno de desarrollo configurado!
echo.
echo 🔧 Para iniciar el backend:
echo    cd backend ^& npm run dev
echo.
echo 🌐 Para iniciar el frontend:
echo    cd frontend ^& npm start
echo.
echo 🗄️ Base de datos ejecutándose en: localhost:5432
goto end

:hybrid_run
echo.
echo 📊 Iniciando base de datos y servicios auxiliares...
docker-compose up -d postgres pgadmin

echo ✅ Servicios auxiliares iniciados!
echo 🗄️ Base de datos: localhost:5432
echo 📊 PgAdmin: http://localhost:5050
echo.
echo Ahora puedes ejecutar backend y frontend en modo desarrollo.
goto end

:clean_all
echo.
echo 🧹 Limpiando contenedores y volúmenes...
docker-compose down -v
docker system prune -f

echo ✅ Limpieza completada!
goto menu

:show_logs
echo.
echo 📋 Mostrando logs de los servicios...
docker-compose logs -f --tail=50
goto end

:exit
echo.
echo 👋 ¡Hasta luego!
exit /b 0

:end
echo.
echo 🎉 ¡SanguApp está listo para usar!
echo.
echo 📚 Documentación adicional:
echo    - README.md: Guía completa del proyecto
echo    - docs/: Documentación técnica
echo.
echo 🆘 ¿Necesitas ayuda?
echo    - GitHub Issues: Reporta problemas
echo    - Email: soporte@sanguapp.com
echo.
echo ¡Que disfrutes usando SanguApp! 🍹
echo.
pause
