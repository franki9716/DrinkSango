const { query } = require('../config/database')

class ProductController {
  // GET /api/products
  static async getProducts(req, res) {
    try {
      const { page = 1, limit = 50, search, category, isAvailable } = req.query
      const organizationId = req.user.organizationId
      const offset = (page - 1) * limit

      let whereClause = 'WHERE p.organization_id = $1'
      const params = [organizationId]
      let paramIndex = 2

      if (search) {
        whereClause += ` AND (p.name ILIKE $${paramIndex} OR p.description ILIKE $${paramIndex})`
        params.push(`%${search}%`)
        paramIndex++
      }

      if (category) {
        whereClause += ` AND p.category = $${paramIndex}`
        params.push(category)
        paramIndex++
      }

      if (isAvailable !== undefined) {
        whereClause += ` AND p.is_available = $${paramIndex}`
        params.push(isAvailable === 'true')
        paramIndex++
      }

      const result = await query(
        `SELECT p.*, 
                COUNT(*) OVER() as total_count,
                CASE WHEN p.stock_quantity <= p.min_stock_alert THEN true ELSE false END as low_stock
         FROM products p
         ${whereClause}
         ORDER BY p.name ASC
         LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
        [...params, limit, offset]
      )

      const products = result.rows.map(row => ({
        id: row.id,
        name: row.name,
        description: row.description,
        price: parseFloat(row.price),
        category: row.category,
        imageUrl: row.image_url,
        stockQuantity: parseInt(row.stock_quantity),
        minStockAlert: parseInt(row.min_stock_alert),
        isAvailable: row.is_available,
        lowStock: row.low_stock,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        totalCount: parseInt(row.total_count) || 0
      }))

      const totalCount = products.length > 0 ? products[0].totalCount : 0

      res.json({
        success: true,
        data: {
          products: products.map(({ totalCount, ...product }) => product),
          pagination: {
            page: parseInt(page),
            limit: parseInt(limit),
            total: totalCount,
            pages: Math.ceil(totalCount / limit)
          }
        }
      })
    } catch (error) {
      console.error('Get products error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // GET /api/products/:id
  static async getProduct(req, res) {
    try {
      const { id } = req.params
      const organizationId = req.user.organizationId

      const result = await query(
        `SELECT p.*,
                CASE WHEN p.stock_quantity <= p.min_stock_alert THEN true ELSE false END as low_stock
         FROM products p
         WHERE p.id = $1 AND p.organization_id = $2`,
        [id, organizationId]
      )

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Producto no encontrado'
        })
      }

      const product = result.rows[0]

      res.json({
        success: true,
        data: {
          product: {
            id: product.id,
            name: product.name,
            description: product.description,
            price: parseFloat(product.price),
            category: product.category,
            imageUrl: product.image_url,
            stockQuantity: parseInt(product.stock_quantity),
            minStockAlert: parseInt(product.min_stock_alert),
            isAvailable: product.is_available,
            lowStock: product.low_stock,
            createdAt: product.created_at,
            updatedAt: product.updated_at
          }
        }
      })
    } catch (error) {
      console.error('Get product error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // POST /api/products
  static async createProduct(req, res) {
    try {
      const { name, description, price, category = 'bebida', imageUrl, stockQuantity = 0, minStockAlert = 5 } = req.body
      const organizationId = req.user.organizationId

      // Only admin and superadmin can create products
      if (!['admin', 'superadmin'].includes(req.user.role)) {
        return res.status(403).json({
          success: false,
          message: 'No tienes permisos para crear productos'
        })
      }

      const result = await query(
        `INSERT INTO products (organization_id, name, description, price, category, image_url, stock_quantity, min_stock_alert)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [organizationId, name, description, price, category, imageUrl, stockQuantity, minStockAlert]
      )

      const product = result.rows[0]

      res.status(201).json({
        success: true,
        message: 'Producto creado exitosamente',
        data: {
          product: {
            id: product.id,
            name: product.name,
            description: product.description,
            price: parseFloat(product.price),
            category: product.category,
            imageUrl: product.image_url,
            stockQuantity: parseInt(product.stock_quantity),
            minStockAlert: parseInt(product.min_stock_alert),
            isAvailable: product.is_available,
            createdAt: product.created_at
          }
        }
      })
    } catch (error) {
      console.error('Create product error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // PUT /api/products/:id
  static async updateProduct(req, res) {
    try {
      const { id } = req.params
      const { name, description, price, category, imageUrl, stockQuantity, minStockAlert, isAvailable } = req.body
      const organizationId = req.user.organizationId

      // Only admin and superadmin can update products
      if (!['admin', 'superadmin'].includes(req.user.role)) {
        return res.status(403).json({
          success: false,
          message: 'No tienes permisos para actualizar productos'
        })
      }

      const result = await query(
        `UPDATE products 
         SET name = $1, description = $2, price = $3, category = $4, image_url = $5, 
             stock_quantity = $6, min_stock_alert = $7, is_available = $8, updated_at = NOW()
         WHERE id = $9 AND organization_id = $10
         RETURNING *`,
        [name, description, price, category, imageUrl, stockQuantity, minStockAlert, isAvailable, id, organizationId]
      )

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Producto no encontrado'
        })
      }

      const product = result.rows[0]

      res.json({
        success: true,
        message: 'Producto actualizado exitosamente',
        data: {
          product: {
            id: product.id,
            name: product.name,
            description: product.description,
            price: parseFloat(product.price),
            category: product.category,
            imageUrl: product.image_url,
            stockQuantity: parseInt(product.stock_quantity),
            minStockAlert: parseInt(product.min_stock_alert),
            isAvailable: product.is_available,
            updatedAt: product.updated_at
          }
        }
      })
    } catch (error) {
      console.error('Update product error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // DELETE /api/products/:id
  static async deleteProduct(req, res) {
    try {
      const { id } = req.params
      const organizationId = req.user.organizationId

      // Only admin and superadmin can delete products
      if (!['admin', 'superadmin'].includes(req.user.role)) {
        return res.status(403).json({
          success: false,
          message: 'No tienes permisos para eliminar productos'
        })
      }

      const result = await query(
        'UPDATE products SET is_available = false WHERE id = $1 AND organization_id = $2 RETURNING id',
        [id, organizationId]
      )

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Producto no encontrado'
        })
      }

      res.json({
        success: true,
        message: 'Producto eliminado exitosamente'
      })
    } catch (error) {
      console.error('Delete product error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }
}

module.exports = ProductController
