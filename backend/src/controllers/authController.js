const { query } = require('../config/database')
const { generateToken, comparePassword } = require('../config/config')
const bcrypt = require('bcrypt')

class AuthController {
  // POST /api/auth/login
  static async login(req, res) {
    try {
      const { email, password } = req.body

      // Find user with organization info
      const userResult = await query(
        `SELECT u.*, o.name as organization_name, o.slug as organization_slug, o.is_active as org_active 
         FROM users u 
         JOIN organizations o ON u.organization_id = o.id 
         WHERE u.email = $1 AND u.is_active = true`,
        [email]
      )

      if (userResult.rows.length === 0) {
        return res.status(401).json({
          success: false,
          message: 'Email o contraseña incorrectos'
        })
      }

      const user = userResult.rows[0]

      // Check if organization is active
      if (!user.org_active) {
        return res.status(401).json({
          success: false,
          message: 'Organización inactiva'
        })
      }

      // Verify password
      const isValidPassword = await comparePassword(password, user.password_hash)
      if (!isValidPassword) {
        return res.status(401).json({
          success: false,
          message: 'Email o contraseña incorrectos'
        })
      }

      // Update last login
      await query(
        'UPDATE users SET last_login_at = NOW() WHERE id = $1',
        [user.id]
      )

      // Generate JWT token
      const token = generateToken({
        userId: user.id,
        email: user.email,
        role: user.role,
        organizationId: user.organization_id
      })

      res.json({
        success: true,
        message: 'Login exitoso',
        data: {
          token,
          user: {
            id: user.id,
            email: user.email,
            fullName: user.full_name,
            role: user.role,
            avatarUrl: user.avatar_url,
            organization: {
              id: user.organization_id,
              name: user.organization_name,
              slug: user.organization_slug
            }
          }
        }
      })
    } catch (error) {
      console.error('Login error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // POST /api/auth/register
  static async register(req, res) {
    try {
      const { email, password, fullName, role = 'operator' } = req.body
      const organizationId = req.user.organizationId

      // Only admin and superadmin can create users
      if (!['admin', 'superadmin'].includes(req.user.role)) {
        return res.status(403).json({
          success: false,
          message: 'No tienes permisos para crear usuarios'
        })
      }

      // Only superadmin can create admin users
      if (role === 'admin' && req.user.role !== 'superadmin') {
        return res.status(403).json({
          success: false,
          message: 'Solo el superadmin puede crear usuarios admin'
        })
      }

      // Hash password
      const passwordHash = await bcrypt.hash(password, 12)

      // Create user
      const result = await query(
        `INSERT INTO users (organization_id, email, password_hash, full_name, role) 
         VALUES ($1, $2, $3, $4, $5) 
         RETURNING id, email, full_name, role, created_at`,
        [organizationId, email, passwordHash, fullName, role]
      )

      const newUser = result.rows[0]

      res.status(201).json({
        success: true,
        message: 'Usuario creado exitosamente',
        data: {
          user: {
            id: newUser.id,
            email: newUser.email,
            fullName: newUser.full_name,
            role: newUser.role,
            createdAt: newUser.created_at
          }
        }
      })
    } catch (error) {
      console.error('Register error:', error)
      
      if (error.code === '23505') {
        return res.status(409).json({
          success: false,
          message: 'Ya existe un usuario con este email en esta organización'
        })
      }
      
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // GET /api/auth/profile
  static async getProfile(req, res) {
    try {
      const userId = req.user.id

      const result = await query(
        `SELECT u.id, u.email, u.full_name, u.role, u.avatar_url, u.last_login_at, u.created_at,
                o.id as organization_id, o.name as organization_name, o.slug as organization_slug
         FROM users u
         JOIN organizations o ON u.organization_id = o.id
         WHERE u.id = $1`,
        [userId]
      )

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Usuario no encontrado'
        })
      }

      const user = result.rows[0]

      res.json({
        success: true,
        data: {
          user: {
            id: user.id,
            email: user.email,
            fullName: user.full_name,
            role: user.role,
            avatarUrl: user.avatar_url,
            lastLoginAt: user.last_login_at,
            createdAt: user.created_at,
            organization: {
              id: user.organization_id,
              name: user.organization_name,
              slug: user.organization_slug
            }
          }
        }
      })
    } catch (error) {
      console.error('Get profile error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // PUT /api/auth/profile
  static async updateProfile(req, res) {
    try {
      const userId = req.user.id
      const { fullName, avatarUrl } = req.body

      const result = await query(
        `UPDATE users 
         SET full_name = $1, avatar_url = $2, updated_at = NOW()
         WHERE id = $3 
         RETURNING id, email, full_name, role, avatar_url`,
        [fullName, avatarUrl, userId]
      )

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Usuario no encontrado'
        })
      }

      const user = result.rows[0]

      res.json({
        success: true,
        message: 'Perfil actualizado exitosamente',
        data: {
          user: {
            id: user.id,
            email: user.email,
            fullName: user.full_name,
            role: user.role,
            avatarUrl: user.avatar_url
          }
        }
      })
    } catch (error) {
      console.error('Update profile error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // POST /api/auth/change-password
  static async changePassword(req, res) {
    try {
      const userId = req.user.id
      const { currentPassword, newPassword } = req.body

      // Get current password hash
      const userResult = await query(
        'SELECT password_hash FROM users WHERE id = $1',
        [userId]
      )

      if (userResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Usuario no encontrado'
        })
      }

      // Verify current password
      const isValidPassword = await comparePassword(currentPassword, userResult.rows[0].password_hash)
      if (!isValidPassword) {
        return res.status(400).json({
          success: false,
          message: 'Contraseña actual incorrecta'
        })
      }

      // Hash new password
      const newPasswordHash = await bcrypt.hash(newPassword, 12)

      // Update password
      await query(
        'UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2',
        [newPasswordHash, userId]
      )

      res.json({
        success: true,
        message: 'Contraseña cambiada exitosamente'
      })
    } catch (error) {
      console.error('Change password error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // POST /api/auth/logout
  static async logout(req, res) {
    // In JWT implementation, logout is handled client-side by removing the token
    // Optionally, you could implement a token blacklist here
    res.json({
      success: true,
      message: 'Logout exitoso'
    })
  }
}

module.exports = AuthController
