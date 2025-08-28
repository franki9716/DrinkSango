# 🍹 SanguApp - Gestión de Consumiciones para Eventos

**SanguApp** es una webapp ligera, funcional y segura para gestionar consumiciones en eventos como bares, comparsas y festivales. Optimizada para tablets Android con soporte para códigos QR y NFC.

## 🚀 Características Principales

### ✅ Funcionalidades Implementadas
- 📱 **Escáner QR integrado** - Lectura con cámara de tablet
- 💳 **Consulta de saldos** - Verificación instantánea del cliente
- 🛒 **Registro de consumiciones** - Deducción automática del saldo
- 👥 **Panel de administración** - CRUD completo de productos y clientes
- 📊 **Reportes básicos** - Ventas, stock y consumiciones
- 🏢 **Multi-tenant** - Soporte para múltiples comparsas/organizaciones
- 🔐 **Seguridad JWT** - Autenticación segura con tokens
- 🐳 **Docker Ready** - Despliegue fácil con Docker Compose

### 🔮 Próximamente (Fase 2)
- 📡 **Soporte NFC** - Lectura de pulseras NFC
- 📈 **Dashboard avanzado** - Estadísticas detalladas
- 📱 **App móvil cliente** - Pedidos remotos desde el móvil

## 🏗️ Arquitectura

```
SanguApp/
├── 🎨 frontend/          # React + TailwindCSS
├── ⚙️  backend/           # Node.js + Express + JWT
├── 🗄️  database/         # PostgreSQL con multi-tenant
├── 📚 docs/             # Documentación
└── 🐳 docker-compose.yml # Orquestación completa
```

## 🚀 Inicio Rápido

### Prerrequisitos
- Docker y Docker Compose
- Node.js 18+ (para desarrollo)

### 🐳 Instalación con Docker
```bash
# Clonar y acceder al directorio
cd DrinkSangu

# Levantar todos los servicios
docker-compose up -d

# Acceder a la aplicación
# Frontend: http://localhost:3000
# Backend API: http://localhost:3001
# Admin Panel: http://localhost:3000/admin
```

### 🏢 Despliegue en Hostinger VPS

**¿Quieres montar SanguApp en tu VPS de Hostinger?** ¡Tenemos una guía completa!

```bash
# En tu VPS Hostinger
ssh root@tu-ip-vps
cd /opt
git clone https://github.com/tu-usuario/sanguapp.git
cd sanguapp

# Ejecutar instalación automática
chmod +x deploy-hostinger.sh
./deploy-hostinger.sh
```

📖 **Guía detallada**: [docs/HOSTINGER-GUIDE.md](docs/HOSTINGER-GUIDE.md)

**Características del despliegue en Hostinger:**
- ✅ SSL automático con Let's Encrypt
- ✅ Backups automáticos diarios
- ✅ Firewall configurado
- ✅ Monitoreo de servicios
- ✅ Optimizado para tablets Android
- ✅ Listo para producción

### Instalación para Desarrollo
```bash
# Backend
cd backend
npm install
npm run dev

# Frontend (nueva terminal)
cd frontend
npm install
npm start
```

## 🎯 Uso de la Aplicación

### Para Operadores (Tablets en Barra)
1. **Escanear QR**: Apuntar cámara al código QR del cliente
2. **Verificar saldo**: Ver información del cliente y saldo disponible
3. **Registrar consumición**: Seleccionar productos y confirmar venta
4. **Actualización automática**: El saldo se actualiza instantáneamente

### Para Administradores
1. **Gestión de productos**: Crear/editar bebidas, precios y stock
2. **Gestión de clientes**: Registrar clientes y asignar códigos QR
3. **Reportes**: Consultar ventas, consumiciones y estado del stock
4. **Multi-tenant**: Crear y gestionar múltiples comparsas

## 🏢 Multi-Tenant

SanguApp está diseñado para soportar múltiples organizaciones:

- **Aislamiento de datos**: Cada comparsa tiene sus propios datos
- **Panel superadmin**: Crear nuevas organizaciones
- **Configuración independiente**: Productos, precios y clientes por organización
- **Escalabilidad**: Fácil despliegue para nuevas comparsas

## 🔐 Seguridad

- ✅ **HTTPS obligatorio** en producción
- ✅ **JWT tokens** para autenticación
- ✅ **Validación server-side** de todos los datos
- ✅ **Protección anti-fraude** para QR/NFC
- ✅ **Rate limiting** en API endpoints
- ✅ **Sanitización de inputs** contra XSS/SQL injection

## 🎨 Tecnologías Utilizadas

### Frontend
- **React 18** - Framework principal
- **TailwindCSS** - Estilos responsive
- **html5-qrcode** - Escáner QR
- **Axios** - Cliente HTTP
- **React Router** - Navegación

### Backend
- **Node.js + Express** - Servidor API
- **JWT** - Autenticación
- **bcrypt** - Hashing de contraseñas
- **helmet** - Seguridad HTTP
- **cors** - Control de acceso

### Base de Datos
- **PostgreSQL** - Base de datos principal
- **Schema multi-tenant** - Aislamiento por organización

### DevOps
- **Docker & Docker Compose** - Containerización
- **nginx** - Proxy reverso y SSL

## 📊 Base de Datos

### Esquema Multi-Tenant
```sql
organizations/          # Comparsas/Asociaciones
├── users/             # Usuarios del sistema
├── customers/         # Clientes con QR/NFC
├── products/          # Bebidas y productos
├── transactions/      # Registro de consumiciones
└── events/           # Eventos/festivales
```

## 🚀 Despliegue en Producción

### Variables de Entorno
```bash
# Backend
JWT_SECRET=tu_secreto_super_seguro
DB_HOST=postgres
DB_NAME=sanguapp
DB_USER=sanguapp
DB_PASS=tu_password_seguro

# Frontend
REACT_APP_API_URL=https://tu-dominio.com/api
```

### SSL/HTTPS
- Configurar certificados SSL en nginx
- Redireccionar HTTP → HTTPS
- Actualizar variables de entorno con URLs HTTPS

## 🤝 Contribuir

1. Fork del repositorio
2. Crear rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -m 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver archivo `LICENSE` para más detalles.

## 🆘 Soporte

- 📧 Email: soporte@sanguapp.com
- 📚 Documentación: `/docs`
- 🐛 Issues: GitHub Issues
- 💬 Comunidad: Discord/Telegram

---

**Desarrollado con ❤️ para la comunidad de comparsas y eventos** 🎭🎉