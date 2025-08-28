# 🚀 Guía Completa de Despliegue en Hostinger VPS

Esta guía te llevará paso a paso para montar SanguApp en tu VPS de Hostinger de manera profesional y segura.

## 📋 Prerrequisitos

### 1. VPS Hostinger
- **Plan recomendado**: VPS Plan 1 o superior (4GB RAM, 100GB SSD)
- **Sistema operativo**: Ubuntu 20.04 LTS o superior
- **IP pública** asignada

### 2. Dominio
- Dominio apuntando a tu VPS (A record)
- Acceso al DNS de tu dominio

### 3. Acceso SSH
- Credenciales de acceso root a tu VPS
- Cliente SSH (PuTTY, Terminal, etc.)

## 🎯 Método 1: Despliegue Automatizado (Recomendado)

### Paso 1: Conectar al VPS
```bash
# Desde tu terminal local
ssh root@TU_IP_VPS
```

### Paso 2: Descargar SanguApp
```bash
# Crear directorio y descargar
cd /opt
git clone https://github.com/TU_USUARIO/sanguapp.git
cd sanguapp

# O subir archivos manualmente
scp -r /ruta/local/DrinkSangu root@TU_IP_VPS:/opt/sanguapp
```

### Paso 3: Ejecutar Script Automatizado
```bash
# Hacer ejecutable el script
chmod +x deploy-hostinger.sh

# Ejecutar instalación
./deploy-hostinger.sh
```

El script te pedirá:
- 🌐 **Tu dominio**: ejemplo.com
- 📧 **Email para SSL**: tu@email.com  
- 🔐 **Password de DB**: password_seguro_123
- 🔑 **JWT Secret**: (se genera automáticamente)

### Paso 4: Configurar DNS
Mientras se ejecuta el script, configura tu dominio:

**En tu panel de DNS (Hostinger, Cloudflare, etc.):**
```
Tipo: A
Nombre: @
Valor: IP_DE_TU_VPS
TTL: 300

Tipo: A  
Nombre: www
Valor: IP_DE_TU_VPS
TTL: 300
```

### Paso 5: ¡Listo!
En 10-15 minutos tendrás SanguApp funcionando en:
- 🌐 **https://tu-dominio.com**
- 🔧 **https://tu-dominio.com/api/health**

## ⚙️ Método 2: Instalación Manual

Si prefieres hacer todo paso a paso:

### 1. Actualizar Sistema
```bash
apt update && apt upgrade -y
apt install -y curl wget git unzip htop nano
```

### 2. Instalar Docker
```bash
# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh && rm get-docker.sh

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 3. Configurar SSL
```bash
# Instalar Certbot
apt install -y snapd
snap install core && snap refresh core
snap install --classic certbot

# Obtener certificado
certbot certonly --standalone -d tu-dominio.com --email tu@email.com --agree-tos
```

### 4. Configurar SanguApp
```bash
cd /opt/sanguapp

# Crear variables de entorno
cp backend/.env.example backend/.env
nano backend/.env  # Editar con tu configuración

# Crear directorio SSL
mkdir -p nginx/ssl
cp /etc/letsencrypt/live/tu-dominio.com/fullchain.pem nginx/ssl/
cp /etc/letsencrypt/live/tu-dominio.com/privkey.pem nginx/ssl/
```

### 5. Ejecutar SanguApp
```bash
# Construir y ejecutar
docker-compose -f docker-compose.hostinger.yml up -d --build

# Verificar estado
docker-compose -f docker-compose.hostinger.yml ps
```

## 🔒 Configuración de Seguridad

### Firewall UFW
```bash
# Configurar firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw enable
```

### Fail2Ban para SSH
```bash
# Instalar y configurar
apt install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

### Actualizaciones Automáticas
```bash
# Configurar actualizaciones de seguridad
apt install -y unattended-upgrades
dpkg-reconfigure unattended-upgrades
```

## 📊 Monitoreo y Mantenimiento

### Ver Logs en Tiempo Real
```bash
cd /opt/sanguapp
docker-compose -f docker-compose.hostinger.yml logs -f
```

### Backup Manual
```bash
# Backup de base de datos
docker exec sanguapp_db_hostinger pg_dump -U sanguapp_prod sanguapp_prod > backup_$(date +%Y%m%d).sql
gzip backup_$(date +%Y%m%d).sql
```

### Comandos Útiles
```bash
# Ver estado de contenedores
docker ps

# Reiniciar servicio específico
docker-compose -f docker-compose.hostinger.yml restart backend

# Ver uso de recursos
docker stats

# Limpiar imágenes no utilizadas
docker system prune -a
```

## 🔧 Troubleshooting

### Error: "No se puede conectar a la base de datos"
```bash
# Verificar logs de PostgreSQL
docker-compose -f docker-compose.hostinger.yml logs postgres

# Verificar conectividad
docker-compose -f docker-compose.hostinger.yml exec backend ping postgres
```

### Error: "SSL certificate not found"
```bash
# Verificar certificados
ls -la /etc/letsencrypt/live/tu-dominio.com/

# Copiar certificados manualmente
cp /etc/letsencrypt/live/tu-dominio.com/*.pem /opt/sanguapp/nginx/ssl/

# Reiniciar nginx
docker-compose -f docker-compose.hostinger.yml restart nginx
```

### Error: "Port already in use"
```bash
# Ver qué está usando el puerto
netstat -tulpn | grep :80
netstat -tulpn | grep :443

# Detener servicios conflictivos
systemctl stop apache2  # Si estaba instalado
systemctl stop nginx    # Si estaba instalado
```

### Error: "No space left on device"
```bash
# Ver uso del disco
df -h

# Limpiar logs antiguos
find /var/log -name "*.log" -mtime +30 -delete

# Limpiar Docker
docker system prune -a
```

## 🚀 Optimización para Producción

### 1. Configurar Backups Automáticos
```bash
# Crear script de backup
cat > /opt/sanguapp/backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker exec sanguapp_db_hostinger pg_dump -U sanguapp_prod sanguapp_prod > /opt/sanguapp/backups/backup_$DATE.sql
gzip /opt/sanguapp/backups/backup_$DATE.sql
find /opt/sanguapp/backups -name "*.sql.gz" -mtime +7 -delete
EOF

chmod +x /opt/sanguapp/backup.sh

# Agregar al crontab (backup diario a las 2 AM)
(crontab -l; echo "0 2 * * * /opt/sanguapp/backup.sh") | crontab -
```

### 2. Monitoreo de Salud
```bash
# Script de health check
cat > /opt/sanguapp/health-check.sh << 'EOF'
#!/bin/bash
if ! curl -f -s https://tu-dominio.com/health > /dev/null; then
    echo "SanguApp Frontend DOWN" | mail -s "ALERT: SanguApp" admin@tu-dominio.com
fi

if ! curl -f -s https://tu-dominio.com/api/health > /dev/null; then
    echo "SanguApp API DOWN" | mail -s "ALERT: SanguApp API" admin@tu-dominio.com
fi
EOF

chmod +x /opt/sanguapp/health-check.sh

# Verificar cada 5 minutos
(crontab -l; echo "*/5 * * * * /opt/sanguapp/health-check.sh") | crontab -
```

### 3. Optimización de Performance
```bash
# Configurar límites de memoria para Docker
echo '{"default-ulimits":{"memlock":{"Name":"memlock","Hard":-1,"Soft":-1}},"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3"}}' > /etc/docker/daemon.json

# Reiniciar Docker
systemctl restart docker
```

## 📱 Configuración Específica para Tablets

### Habilitar Cámara en HTTPS
SanguApp necesita HTTPS para acceder a la cámara. Asegúrate de que:

1. ✅ Tu dominio tiene certificado SSL válido
2. ✅ La tablet puede acceder a tu dominio
3. ✅ El navegador permite acceso a cámara

### Configuración de Red Local
Si usas tablets en la misma red local:

```bash
# En el archivo /opt/sanguapp/backend/.env
# Agregar la IP local del VPS al CORS_ORIGIN
CORS_ORIGIN=https://tu-dominio.com,http://IP_LOCAL_VPS:3000
```

## 💰 Costos Estimados en Hostinger

- **VPS Plan 1**: ~€3.99/mes
- **Dominio .com**: ~€8.99/año  
- **Total primer año**: ~€56.87

## 🆘 Soporte

Si tienes problemas:

1. **Logs**: Siempre revisa primero los logs
   ```bash
   docker-compose -f docker-compose.hostinger.yml logs --tail=100
   ```

2. **Documentación**: Consulta `/opt/sanguapp/docs/`

3. **Comunidad**: GitHub Issues o Discord

4. **Soporte directo**: soporte@sanguapp.com

---

## ✅ Checklist Final

- [ ] VPS creado y accesible por SSH
- [ ] Dominio apuntando al VPS
- [ ] Docker y Docker Compose instalados
- [ ] SSL configurado con Let's Encrypt
- [ ] SanguApp ejecutándose sin errores
- [ ] Frontend accesible via HTTPS
- [ ] API respondiendo correctamente
- [ ] Backups automáticos configurados
- [ ] Firewall configurado
- [ ] Credenciales por defecto cambiadas
- [ ] Organización configurada
- [ ] Productos y clientes de prueba agregados
- [ ] Escáner QR probado desde tablet

¡Una vez completado este checklist, tu SanguApp estará funcionando profesionalmente en Hostinger! 🎉

---

**¿Algún paso no quedó claro?** No dudes en contactarnos. ¡Estamos aquí para ayudarte! 💪🍹
