const jwt = require('jsonwebtoken')
const bcrypt = require('bcrypt')

// JWT Configuration
const JWT_SECRET = process.env.JWT_SECRET || 'fallback_secret_change_in_production'
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d'
const BCRYPT_ROUNDS = parseInt(process.env.BCRYPT_ROUNDS) || 12

// Generate JWT token
const generateToken = (payload) => {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN })
}

// Verify JWT token
const verifyToken = (token) => {
  return jwt.verify(token, JWT_SECRET)
}

// Hash password
const hashPassword = async (password) => {
  return await bcrypt.hash(password, BCRYPT_ROUNDS)
}

// Compare password
const comparePassword = async (password, hashedPassword) => {
  return await bcrypt.compare(password, hashedPassword)
}

// App configuration
const config = {
  port: process.env.PORT || 3001,
  nodeEnv: process.env.NODE_ENV || 'development',
  corsOrigin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  apiRateLimit: parseInt(process.env.API_RATE_LIMIT) || 100,
  maxFileSize: process.env.MAX_FILE_SIZE || '5MB',
  uploadPath: process.env.UPLOAD_PATH || './uploads',
  
  // Security headers
  security: {
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'"],
        imgSrc: ["'self'", 'data:', 'https:'],
        connectSrc: ["'self'"],
        fontSrc: ["'self'"],
        objectSrc: ["'none'"],
        mediaSrc: ["'self'"],
        frameSrc: ["'none'"]
      }
    },
    crossOriginEmbedderPolicy: false
  }
}

module.exports = {
  config,
  generateToken,
  verifyToken,
  hashPassword,
  comparePassword
}
