const { verifyToken } = require('../config/config')
const { query } = require('../config/database')

// Middleware to verify JWT token and extract user information
const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization']
    const token = authHeader && authHeader.split(' ')[1] // Bearer TOKEN

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Token de acceso requerido'
      })
    }

    const decoded = verifyToken(token)
    
    // Get user information from database
    const userResult = await query(
      'SELECT u.*, o.name as organization_name, o.slug as organization_slug FROM users u JOIN organizations o ON u.organization_id = o.id WHERE u.id = $1 AND u.is_active = true',
      [decoded.userId]
    )

    if (userResult.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Usuario no válido o inactivo'
      })
    }

    // Attach user info to request
    req.user = {
      id: userResult.rows[0].id,
      email: userResult.rows[0].email,
      fullName: userResult.rows[0].full_name,
      role: userResult.rows[0].role,
      organizationId: userResult.rows[0].organization_id,
      organizationName: userResult.rows[0].organization_name,
      organizationSlug: userResult.rows[0].organization_slug
    }

    next()
  } catch (error) {
    console.error('Auth middleware error:', error)
    return res.status(403).json({
      success: false,
      message: 'Token no válido'
    })
  }
}

// Middleware to check user roles
const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      })
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Permisos insuficientes'
      })
    }

    next()
  }
}

// Middleware to ensure user can only access their organization data
const requireSameOrganization = (req, res, next) => {
  const organizationId = req.params.organizationId || req.body.organizationId || req.query.organizationId

  if (req.user.role === 'superadmin') {
    // Superadmin can access any organization
    return next()
  }

  if (organizationId && organizationId !== req.user.organizationId) {
    return res.status(403).json({
      success: false,
      message: 'No tienes permisos para acceder a los datos de otra organización'
    })
  }

  next()
}

module.exports = {
  authenticateToken,
  requireRole,
  requireSameOrganization
}
