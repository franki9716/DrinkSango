const rateLimit = require('express-rate-limit')
const { body, validationResult } = require('express-validator')

// Rate limiting middleware
const createRateLimiter = (windowMs = 15 * 60 * 1000, max = 100) => {
  return rateLimit({
    windowMs, // 15 minutes by default
    max, // limit each IP to max requests per windowMs
    message: {
      success: false,
      message: 'Demasiadas peticiones desde esta IP, intenta de nuevo más tarde'
    },
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false // Disable the `X-RateLimit-*` headers
  })
}

// Validation error handler middleware
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req)
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Errores de validación',
      errors: errors.array()
    })
  }
  next()
}

// Common validation rules
const validationRules = {
  // Auth validations
  login: [
    body('email').isEmail().normalizeEmail().withMessage('Email válido requerido'),
    body('password').isLength({ min: 6 }).withMessage('La contraseña debe tener al menos 6 caracteres')
  ],
  
  register: [
    body('email').isEmail().normalizeEmail().withMessage('Email válido requerido'),
    body('password').isLength({ min: 6 }).withMessage('La contraseña debe tener al menos 6 caracteres'),
    body('fullName').trim().isLength({ min: 2 }).withMessage('Nombre completo requerido'),
    body('role').optional().isIn(['admin', 'operator']).withMessage('Rol no válido')
  ],

  // Customer validations
  createCustomer: [
    body('fullName').trim().isLength({ min: 2 }).withMessage('Nombre completo requerido'),
    body('email').optional().isEmail().normalizeEmail().withMessage('Email válido requerido'),
    body('phone').optional().isMobilePhone('es-ES').withMessage('Teléfono válido requerido'),
    body('initialBalance').isFloat({ min: 0 }).withMessage('Saldo inicial debe ser mayor o igual a 0'),
    body('qrCode').trim().isLength({ min: 5 }).withMessage('Código QR requerido')
  ],

  // Product validations
  createProduct: [
    body('name').trim().isLength({ min: 2 }).withMessage('Nombre del producto requerido'),
    body('price').isFloat({ min: 0 }).withMessage('Precio debe ser mayor o igual a 0'),
    body('category').optional().isIn(['bebida', 'comida', 'merchandising']).withMessage('Categoría no válida'),
    body('stockQuantity').optional().isInt({ min: 0 }).withMessage('Stock debe ser mayor o igual a 0')
  ],

  // Transaction validations
  createTransaction: [
    body('customerId').isUUID().withMessage('ID de cliente válido requerido'),
    body('items').isArray({ min: 1 }).withMessage('Al menos un producto requerido'),
    body('items.*.productId').isUUID().withMessage('ID de producto válido requerido'),
    body('items.*.quantity').isInt({ min: 1 }).withMessage('Cantidad debe ser mayor a 0'),
    body('paymentMethod').optional().isIn(['balance', 'cash', 'card']).withMessage('Método de pago no válido')
  ],

  // Organization validations
  createOrganization: [
    body('name').trim().isLength({ min: 2 }).withMessage('Nombre de organización requerido'),
    body('slug').trim().isLength({ min: 2 }).matches(/^[a-z0-9-]+$/).withMessage('Slug debe contener solo letras, números y guiones'),
    body('contactEmail').isEmail().normalizeEmail().withMessage('Email de contacto válido requerido')
  ]
}

// Security middleware
const securityHeaders = (req, res, next) => {
  res.set({
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Referrer-Policy': 'strict-origin-when-cross-origin'
  })
  next()
}

// Error handling middleware
const errorHandler = (err, req, res, next) => {
  console.error('Error stack:', err.stack)

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      success: false,
      message: 'Token no válido'
    })
  }

  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      success: false,
      message: 'Token expirado'
    })
  }

  // Database errors
  if (err.code === '23505') { // PostgreSQL unique constraint violation
    return res.status(409).json({
      success: false,
      message: 'Ya existe un registro con estos datos'
    })
  }

  if (err.code === '23503') { // PostgreSQL foreign key constraint violation
    return res.status(400).json({
      success: false,
      message: 'Referencia no válida'
    })
  }

  // Default error
  res.status(err.status || 500).json({
    success: false,
    message: process.env.NODE_ENV === 'development' ? err.message : 'Error interno del servidor',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  })
}

module.exports = {
  createRateLimiter,
  handleValidationErrors,
  validationRules,
  securityHeaders,
  errorHandler
}
