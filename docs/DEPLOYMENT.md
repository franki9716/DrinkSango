# 🚀 Guía de Despliegue - SanguApp

Esta guía te ayudará a desplegar SanguApp en producción de manera segura y eficiente.

## 🎯 Requisitos del Sistema

### Servidor Recomendado
- **CPU:** 2 vCPU mínimo, 4 vCPU recomendado
- **RAM:** 4 GB mínimo, 8 GB recomendado  
- **Almacenamiento:** 50 GB SSD mínimo
- **OS:** Ubuntu 20.04 LTS o superior
- **Red:** Conexión estable con IP pública

### Software Necesario
- Docker 20.10+
- Docker Compose 2.0+
- Nginx (si no usas el proxy incluido)
- Certbot para SSL (Let's Encrypt)

## 🔐 Configuración de Producción

### Variables de Entorno Seguras
```bash
# Generar secretos seguros
openssl rand -base64 64  # Para JWT_SECRET
openssl rand -base64 32  # Para DB_PASSWORD
```

### Configuración SSL
```bash
# Let's Encrypt
sudo certbot --nginx -d tu-dominio.com
```

### Desplegar
```bash
# Clonar y configurar
git clone https://github.com/tu-repo/sanguapp.git
cd sanguapp

# Configurar variables de producción
cp .env.example .env.production
# Editar variables según tu entorno

# Desplegar
docker-compose -f docker-compose.prod.yml up -d --build
```

## 📊 Monitoreo y Backups

### Backup Automático
```bash
#!/bin/bash
# scripts/backup.sh
DATE=$(date +%Y%m%d_%H%M%S)
docker exec sanguapp_db pg_dump -U usuario database > backup_$DATE.sql
gzip backup_$DATE.sql
```

### Health Checks
```bash
# Verificar estado de servicios
curl -f https://tu-dominio.com/api/health
```

## 🔒 Seguridad

- Firewall configurado (puertos 80, 443, 22)
- Certificados SSL válidos
- Variables de entorno seguras
- Backups regulares
- Monitoreo de logs

¡Tu instalación está lista para producción! 🎉
