const { query } = require('../config/database')

class CustomerController {
  // GET /api/customers
  static async getCustomers(req, res) {
    try {
      const { page = 1, limit = 50, search, eventId, isActive } = req.query
      const organizationId = req.user.organizationId
      const offset = (page - 1) * limit

      let whereClause = 'WHERE c.organization_id = $1'
      const params = [organizationId]
      let paramIndex = 2

      if (search) {
        whereClause += ` AND (c.full_name ILIKE $${paramIndex} OR c.email ILIKE $${paramIndex} OR c.qr_code ILIKE $${paramIndex})`
        params.push(`%${search}%`)
        paramIndex++
      }

      if (eventId) {
        whereClause += ` AND c.event_id = $${paramIndex}`
        params.push(eventId)
        paramIndex++
      }

      if (isActive !== undefined) {
        whereClause += ` AND c.is_active = $${paramIndex}`
        params.push(isActive === 'true')
        paramIndex++
      }

      const result = await query(
        `SELECT c.*, e.name as event_name,
                COUNT(*) OVER() as total_count
         FROM customers c
         LEFT JOIN events e ON c.event_id = e.id
         ${whereClause}
         ORDER BY c.registered_at DESC
         LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
        [...params, limit, offset]
      )

      const customers = result.rows.map(row => ({
        id: row.id,
        fullName: row.full_name,
        email: row.email,
        phone: row.phone,
        qrCode: row.qr_code,
        nfcId: row.nfc_id,
        initialBalance: parseFloat(row.initial_balance),
        currentBalance: parseFloat(row.current_balance),
        totalSpent: parseFloat(row.total_spent),
        isActive: row.is_active,
        registeredAt: row.registered_at,
        lastActivityAt: row.last_activity_at,
        event: row.event_name ? {
          id: row.event_id,
          name: row.event_name
        } : null,
        totalCount: parseInt(row.total_count) || 0
      }))

      const totalCount = customers.length > 0 ? customers[0].totalCount : 0

      res.json({
        success: true,
        data: {
          customers: customers.map(({ totalCount, ...customer }) => customer),
          pagination: {
            page: parseInt(page),
            limit: parseInt(limit),
            total: totalCount,
            pages: Math.ceil(totalCount / limit)
          }
        }
      })
    } catch (error) {
      console.error('Get customers error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // GET /api/customers/:id
  static async getCustomer(req, res) {
    try {
      const { id } = req.params
      const organizationId = req.user.organizationId

      const result = await query(
        `SELECT c.*, e.name as event_name
         FROM customers c
         LEFT JOIN events e ON c.event_id = e.id
         WHERE c.id = $1 AND c.organization_id = $2`,
        [id, organizationId]
      )

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Cliente no encontrado'
        })
      }

      const customer = result.rows[0]

      res.json({
        success: true,
        data: {
          customer: {
            id: customer.id,
            fullName: customer.full_name,
            email: customer.email,
            phone: customer.phone,
            qrCode: customer.qr_code,
            nfcId: customer.nfc_id,
            initialBalance: parseFloat(customer.initial_balance),
            currentBalance: parseFloat(customer.current_balance),
            totalSpent: parseFloat(customer.total_spent),
            isActive: customer.is_active,
            registeredAt: customer.registered_at,
            lastActivityAt: customer.last_activity_at,
            event: customer.event_name ? {
              id: customer.event_id,
              name: customer.event_name
            } : null
          }
        }
      })
    } catch (error) {
      console.error('Get customer error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // GET /api/customers/qr/:qrCode
  static async getCustomerByQR(req, res) {
    try {
      const { qrCode } = req.params
      const organizationId = req.user.organizationId

      const result = await query(
        `SELECT c.*, e.name as event_name
         FROM customers c
         LEFT JOIN events e ON c.event_id = e.id
         WHERE c.qr_code = $1 AND c.organization_id = $2 AND c.is_active = true`,
        [qrCode, organizationId]
      )

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Cliente no encontrado o inactivo'
        })
      }

      const customer = result.rows[0]

      res.json({
        success: true,
        data: {
          customer: {
            id: customer.id,
            fullName: customer.full_name,
            email: customer.email,
            qrCode: customer.qr_code,
            currentBalance: parseFloat(customer.current_balance),
            totalSpent: parseFloat(customer.total_spent),
            event: customer.event_name ? {
              id: customer.event_id,
              name: customer.event_name
            } : null
          }
        }
      })
    } catch (error) {
      console.error('Get customer by QR error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // POST /api/customers
  static async createCustomer(req, res) {
    try {
      const { fullName, email, phone, qrCode, nfcId, initialBalance, eventId } = req.body
      const organizationId = req.user.organizationId

      const result = await query(
        `INSERT INTO customers (organization_id, event_id, full_name, email, phone, qr_code, nfc_id, initial_balance, current_balance)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $8)
         RETURNING *`,
        [organizationId, eventId, fullName, email, phone, qrCode, nfcId, initialBalance]
      )

      const customer = result.rows[0]

      res.status(201).json({
        success: true,
        message: 'Cliente creado exitosamente',
        data: {
          customer: {
            id: customer.id,
            fullName: customer.full_name,
            email: customer.email,
            phone: customer.phone,
            qrCode: customer.qr_code,
            nfcId: customer.nfc_id,
            initialBalance: parseFloat(customer.initial_balance),
            currentBalance: parseFloat(customer.current_balance),
            registeredAt: customer.registered_at
          }
        }
      })
    } catch (error) {
      console.error('Create customer error:', error)
      
      if (error.code === '23505') {
        return res.status(409).json({
          success: false,
          message: 'Ya existe un cliente con este código QR o NFC'
        })
      }
      
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // PUT /api/customers/:id
  static async updateCustomer(req, res) {
    try {
      const { id } = req.params
      const { fullName, email, phone, qrCode, nfcId, isActive } = req.body
      const organizationId = req.user.organizationId

      const result = await query(
        `UPDATE customers 
         SET full_name = $1, email = $2, phone = $3, qr_code = $4, nfc_id = $5, is_active = $6
         WHERE id = $7 AND organization_id = $8
         RETURNING *`,
        [fullName, email, phone, qrCode, nfcId, isActive, id, organizationId]
      )

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Cliente no encontrado'
        })
      }

      const customer = result.rows[0]

      res.json({
        success: true,
        message: 'Cliente actualizado exitosamente',
        data: {
          customer: {
            id: customer.id,
            fullName: customer.full_name,
            email: customer.email,
            phone: customer.phone,
            qrCode: customer.qr_code,
            nfcId: customer.nfc_id,
            isActive: customer.is_active
          }
        }
      })
    } catch (error) {
      console.error('Update customer error:', error)
      
      if (error.code === '23505') {
        return res.status(409).json({
          success: false,
          message: 'Ya existe un cliente con este código QR o NFC'
        })
      }
      
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // POST /api/customers/:id/top-up
  static async topUpBalance(req, res) {
    try {
      const { id } = req.params
      const { amount } = req.body
      const organizationId = req.user.organizationId
      const operatorId = req.user.id

      if (amount <= 0) {
        return res.status(400).json({
          success: false,
          message: 'El monto debe ser mayor a 0'
        })
      }

      // Check if customer exists
      const customerResult = await query(
        'SELECT * FROM customers WHERE id = $1 AND organization_id = $2 AND is_active = true',
        [id, organizationId]
      )

      if (customerResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Cliente no encontrado o inactivo'
        })
      }

      // Create top-up transaction
      await query(
        `INSERT INTO transactions (organization_id, customer_id, operator_id, transaction_type, total_amount, payment_method)
         VALUES ($1, $2, $3, 'top_up', $4, 'cash')`,
        [organizationId, id, operatorId, amount]
      )

      // Get updated customer balance
      const updatedCustomer = await query(
        'SELECT current_balance FROM customers WHERE id = $1',
        [id]
      )

      res.json({
        success: true,
        message: 'Saldo recargado exitosamente',
        data: {
          newBalance: parseFloat(updatedCustomer.rows[0].current_balance)
        }
      })
    } catch (error) {
      console.error('Top up balance error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }

  // DELETE /api/customers/:id
  static async deleteCustomer(req, res) {
    try {
      const { id } = req.params
      const organizationId = req.user.organizationId

      // Only admin and superadmin can delete customers
      if (!['admin', 'superadmin'].includes(req.user.role)) {
        return res.status(403).json({
          success: false,
          message: 'No tienes permisos para eliminar clientes'
        })
      }

      const result = await query(
        'UPDATE customers SET is_active = false WHERE id = $1 AND organization_id = $2 RETURNING id',
        [id, organizationId]
      )

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'Cliente no encontrado'
        })
      }

      res.json({
        success: true,
        message: 'Cliente eliminado exitosamente'
      })
    } catch (error) {
      console.error('Delete customer error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }
}

module.exports = CustomerController
