# 🚀 Guía de Despliegue: toptraining.es

## ✅ Configuración Completa para tu VPS

**Dominio**: toptraining.es  
**IP VPS**: 46.202.171.156  
**SSL**: Automático con Let's Encrypt  

## 📋 Pasos para Desplegar

### 1️⃣ Configurar DNS (PRIMER PASO)

**En tu panel de Hostinger:**
1. Ve a **Dominios → toptraining.es → Gestionar**
2. Clic en **DNS / Nameservers**
3. **Agregar/Modificar estos registros:**

```dns
Tipo: A
Nombre: @
Valor: 46.202.171.156
TTL: 300

Tipo: A
Nombre: www  
Valor: 46.202.171.156
TTL: 300
```

⏰ **Esperar 5-30 minutos** para propagación DNS

### 2️⃣ Conectar al VPS

```bash
# Desde tu terminal local
ssh root@46.202.171.156

# Si es la primera vez, aceptar la huella digital
```

### 3️⃣ Subir SanguApp al VPS

**Opción A: Con Git (Recomendado)**
```bash
# En el VPS
cd /opt
git clone https://github.com/TU_USUARIO/sanguapp.git
cd sanguapp
```

**Opción B: Subir archivos directamente**
```bash
# Desde tu PC local (nueva terminal)
scp -r C:\Users\Francisco\Desktop\DrinkSangu root@46.202.171.156:/opt/sanguapp

# Volver al terminal del VPS
cd /opt/sanguapp
```

### 4️⃣ Ejecutar Instalación Automática

```bash
# En el VPS, dentro de /opt/sanguapp
chmod +x deploy-toptraining.sh
./deploy-toptraining.sh
```

**El script te pedirá:**
- 📧 **Email para SSL**: tu@email.com
- 🔐 **Password DB**: (crear password seguro)
- 🔑 **JWT Secret**: (Enter para generar automáticamente)

### 5️⃣ ¡Listo! 🎉

En **10-15 minutos** tendrás SanguApp funcionando:

- 🌐 **Frontend**: https://toptraining.es
- 🔧 **API**: https://toptraining.es/api/health
- 📊 **Admin**: https://toptraining.es/admin

## 🔐 Credenciales por Defecto

```
👤 Admin:
   Email: admin@andaluces.com
   Password: admin123

👤 Operador:
   Email: operador@andaluces.com  
   Password: operador123
```

## 🛠️ Comandos de Mantenimiento

```bash
# Ver estado
cd /opt/sanguapp
docker-compose -f docker-compose.toptraining.yml ps

# Ver logs
docker-compose -f docker-compose.toptraining.yml logs -f

# Reiniciar todo
docker-compose -f docker-compose.toptraining.yml restart

# Script de mantenimiento completo
chmod +x maintenance-toptraining.sh
./maintenance-toptraining.sh
```

## 🔧 Troubleshooting

### Error: "DNS no resuelve"
```bash
# Verificar propagación DNS
nslookup toptraining.es
dig toptraining.es

# Online: https://www.whatsmydns.net/#A/toptraining.es
```

### Error: "SSL no funciona"
```bash
# Verificar certificados
certbot certificates

# Renovar manualmente
certbot renew --force-renewal
cp /etc/letsencrypt/live/toptraining.es/*.pem /opt/sanguapp/nginx/ssl/
docker-compose -f docker-compose.toptraining.yml restart nginx
```

### Error: "No se conecta a la DB"
```bash
# Ver logs de PostgreSQL
docker logs sanguapp_db_toptraining

# Reiniciar solo la base de datos
docker-compose -f docker-compose.toptraining.yml restart postgres
```

### Error: "Puerto ocupado"
```bash
# Ver qué usa el puerto 80/443
netstat -tulpn | grep :80
netstat -tulpn | grep :443

# Detener servicios conflictivos
systemctl stop apache2
systemctl stop nginx
```

## 📊 Monitoreo Post-Instalación

### URLs para verificar:
- ✅ https://toptraining.es (debe mostrar SanguApp)
- ✅ https://toptraining.es/health (debe mostrar "OK")
- ✅ https://toptraining.es/api/health (debe mostrar JSON)

### Herramientas online:
- 🌍 **DNS**: https://www.whatsmydns.net/#A/toptraining.es
- 🔍 **SSL**: https://www.ssllabs.com/ssltest/analyze.html?d=toptraining.es
- ⚡ **Speed**: https://gtmetrix.com/

## 🎯 Próximos Pasos

1. **Cambiar credenciales por defecto**
2. **Configurar tu organización/comparsa**
3. **Agregar productos (bebidas, comida)**
4. **Crear clientes con códigos QR**
5. **Probar escáner QR desde tablet Android**

## 🆘 Soporte

- 📧 **Email**: soporte@sanguapp.com
- 📖 **Docs**: https://github.com/TU_USUARIO/sanguapp/docs
- 🐛 **Issues**: https://github.com/TU_USUARIO/sanguapp/issues

---

## ⚡ Resumen Ejecutivo

```bash
# 1. Configurar DNS (A record: @ → 46.202.171.156)
# 2. SSH al VPS
ssh root@46.202.171.156

# 3. Subir código
git clone https://github.com/TU_USUARIO/sanguapp.git /opt/sanguapp
cd /opt/sanguapp

# 4. Ejecutar instalación
./deploy-toptraining.sh

# 5. ¡Acceder a https://toptraining.es!
```

**🍹 ¡SanguApp estará funcionando en tu dominio en menos de 15 minutos!** ✨
