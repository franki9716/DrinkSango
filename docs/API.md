# 📱 SanguApp - API Reference

## 🔑 Autenticación

Todas las rutas protegidas requieren un token JWT en el header:
```
Authorization: Bearer YOUR_JWT_TOKEN
```

## 🚪 Auth Endpoints

### POST /api/auth/login
Iniciar sesión de usuario.

**Request Body:**
```json
{
  "email": "admin@andaluces.com",
  "password": "admin123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Login exitoso",
  "data": {
    "token": "jwt_token_here",
    "user": {
      "id": "uuid",
      "email": "admin@andaluces.com",
      "fullName": "Administrador",
      "role": "admin",
      "organization": {
        "id": "uuid",
        "name": "Comparsa Los Andaluces",
        "slug": "andaluces"
      }
    }
  }
}
```

### GET /api/auth/profile
Obtener perfil del usuario autenticado.

**Headers:** `Authorization: Bearer TOKEN`

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "admin@andaluces.com",
      "fullName": "Administrador",
      "role": "admin",
      "organization": {
        "id": "uuid",
        "name": "Comparsa Los Andaluces",
        "slug": "andaluces"
      }
    }
  }
}
```

## 👥 Customer Endpoints

### GET /api/customers
Listar clientes con paginación.

**Headers:** `Authorization: Bearer TOKEN`

**Query Parameters:**
- `page`: Número de página (default: 1)
- `limit`: Elementos por página (default: 50)
- `search`: Buscar por nombre, email o QR
- `isActive`: true/false

**Response:**
```json
{
  "success": true,
  "data": {
    "customers": [
      {
        "id": "uuid",
        "fullName": "Juan Pérez",
        "email": "juan@email.com",
        "qrCode": "QR001ANDALUCES",
        "currentBalance": 50.00,
        "totalSpent": 25.50,
        "isActive": true,
        "registeredAt": "2024-01-15T10:30:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "total": 100,
      "pages": 2
    }
  }
}
```

### GET /api/customers/qr/:qrCode
Obtener cliente por código QR (usado en el escáner).

**Headers:** `Authorization: Bearer TOKEN`

**Response:**
```json
{
  "success": true,
  "data": {
    "customer": {
      "id": "uuid",
      "fullName": "Juan Pérez",
      "email": "juan@email.com",
      "qrCode": "QR001ANDALUCES",
      "currentBalance": 50.00,
      "totalSpent": 25.50,
      "event": {
        "id": "uuid",
        "name": "Carnaval 2025"
      }
    }
  }
}
```

### POST /api/customers
Crear nuevo cliente.

**Headers:** `Authorization: Bearer TOKEN`

**Permissions:** Admin, SuperAdmin

**Request Body:**
```json
{
  "fullName": "María González",
  "email": "maria@email.com",
  "phone": "+34600123456",
  "qrCode": "QR002ANDALUCES",
  "initialBalance": 75.00,
  "eventId": "uuid"
}
```

### POST /api/customers/:id/top-up
Recargar saldo de cliente.

**Headers:** `Authorization: Bearer TOKEN`

**Request Body:**
```json
{
  "amount": 25.00
}
```

**Response:**
```json
{
  "success": true,
  "message": "Saldo recargado exitosamente",
  "data": {
    "newBalance": 100.00
  }
}
```

## 📦 Product Endpoints

### GET /api/products
Listar productos.

**Headers:** `Authorization: Bearer TOKEN`

**Query Parameters:**
- `page`: Número de página
- `limit`: Elementos por página
- `search`: Buscar por nombre o descripción
- `category`: bebida, comida, merchandising
- `isAvailable`: true/false

**Response:**
```json
{
  "success": true,
  "data": {
    "products": [
      {
        "id": "uuid",
        "name": "Cerveza Estrella",
        "description": "Cerveza fría de barril",
        "price": 2.50,
        "category": "bebida",
        "stockQuantity": 100,
        "isAvailable": true,
        "lowStock": false
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "total": 20,
      "pages": 1
    }
  }
}
```

### POST /api/products
Crear nuevo producto.

**Headers:** `Authorization: Bearer TOKEN`

**Permissions:** Admin, SuperAdmin

**Request Body:**
```json
{
  "name": "Tinto de Verano",
  "description": "Tinto con limón y hielo",
  "price": 3.00,
  "category": "bebida",
  "stockQuantity": 50,
  "minStockAlert": 10
}
```

## 💰 Transaction Endpoints

### POST /api/transactions
Crear nueva transacción (venta).

**Headers:** `Authorization: Bearer TOKEN`

**Request Body:**
```json
{
  "customerId": "uuid",
  "items": [
    {
      "productId": "uuid",
      "quantity": 2
    },
    {
      "productId": "uuid",
      "quantity": 1
    }
  ],
  "paymentMethod": "balance",
  "notes": "Venta desde tablet"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Transacción creada exitosamente",
  "data": {
    "transaction": {
      "id": "uuid",
      "totalAmount": 8.00,
      "createdAt": "2024-01-15T14:30:00Z"
    },
    "newBalance": 42.00
  }
}
```

### GET /api/transactions/stats/daily
Obtener estadísticas del día.

**Headers:** `Authorization: Bearer TOKEN`

**Query Parameters:**
- `date`: YYYY-MM-DD (default: hoy)

**Response:**
```json
{
  "success": true,
  "data": {
    "stats": {
      "date": "2024-01-15",
      "totalSales": 25,
      "totalRevenue": 187.50,
      "uniqueCustomers": 15
    }
  }
}
```

## ⚠️ Error Responses

Todos los endpoints pueden devolver estos errores:

**401 Unauthorized:**
```json
{
  "success": false,
  "message": "Token de acceso requerido"
}
```

**403 Forbidden:**
```json
{
  "success": false,
  "message": "Permisos insuficientes"
}
```

**404 Not Found:**
```json
{
  "success": false,
  "message": "Recurso no encontrado"
}
```

**400 Bad Request:**
```json
{
  "success": false,
  "message": "Errores de validación",
  "errors": [
    {
      "field": "email",
      "message": "Email válido requerido"
    }
  ]
}
```

**500 Internal Server Error:**
```json
{
  "success": false,
  "message": "Error interno del servidor"
}
```

## 🔐 Roles y Permisos

### SuperAdmin
- Acceso completo a todas las funciones
- Puede crear organizaciones
- Puede crear usuarios admin

### Admin
- Gestión completa de su organización
- CRUD de productos y clientes
- Ver estadísticas y reportes
- Crear usuarios operator

### Operator
- Escáner QR y procesamiento de ventas
- Ver información de clientes
- Ver productos disponibles
- Recargar saldos de clientes

## 📊 Rate Limiting

- Endpoints generales: 100 requests por 15 minutos
- Endpoints de auth: 20 requests por 15 minutos

## 🌐 CORS

La API acepta requests desde:
- http://localhost:3000 (desarrollo)
- Dominio de producción configurado

## 🔄 Webhooks (Futuro)

En versiones futuras se planea añadir webhooks para:
- Notificaciones de stock bajo
- Alertas de transacciones grandes
- Informes diarios automáticos
