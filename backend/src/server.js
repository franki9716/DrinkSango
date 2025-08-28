const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const morgan = require('morgan')
const compression = require('compression')
require('dotenv').config()

const { config } = require('./config/config')
const { createRateLimiter, securityHeaders, errorHandler } = require('./middleware/validation')
const { authenticateToken } = require('./middleware/auth')

// Import routes
const authRoutes = require('./routes/auth')
const customerRoutes = require('./routes/customers')
const productRoutes = require('./routes/products')
const transactionRoutes = require('./routes/transactions')

const app = express()

// Security middleware
app.use(helmet({
  contentSecurityPolicy: config.security.contentSecurityPolicy,
  crossOriginEmbedderPolicy: config.security.crossOriginEmbedderPolicy
}))
app.use(securityHeaders)

// CORS configuration
app.use(cors({
  origin: config.corsOrigin.split(','),
  credentials: true,
  optionsSuccessStatus: 200
}))

// Rate limiting
const generalLimiter = createRateLimiter(15 * 60 * 1000, config.apiRateLimit) // 15 minutes
const authLimiter = createRateLimiter(15 * 60 * 1000, 20) // 20 requests per 15 minutes for auth

// Basic middleware
app.use(compression())
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true }))

// Logging
if (config.nodeEnv === 'development') {
  app.use(morgan('dev'))
} else {
  app.use(morgan('combined'))
}

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    message: 'SanguApp API is running',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    environment: config.nodeEnv
  })
})

// Public routes (no auth required)
app.use('/api/auth', authLimiter, authRoutes)

// Protected routes (require authentication)
app.use('/api/customers', generalLimiter, authenticateToken, customerRoutes)
app.use('/api/products', generalLimiter, authenticateToken, productRoutes)
app.use('/api/transactions', generalLimiter, authenticateToken, transactionRoutes)

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint no encontrado',
    path: req.originalUrl
  })
})

// Global error handler
app.use(errorHandler)

// Start server
const PORT = config.port
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 SanguApp API server running on port ${PORT}`)
  console.log(`📊 Environment: ${config.nodeEnv}`)
  console.log(`🔗 Health check: http://localhost:${PORT}/api/health`)
  
  if (config.nodeEnv === 'development') {
    console.log(`📋 API Base URL: http://localhost:${PORT}/api`)
    console.log(`🔐 Auth endpoints: http://localhost:${PORT}/api/auth`)
  }
})

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, shutting down gracefully')
  process.exit(0)
})

process.on('SIGINT', () => {
  console.log('🛑 SIGINT received, shutting down gracefully')
  process.exit(0)
})

module.exports = app
