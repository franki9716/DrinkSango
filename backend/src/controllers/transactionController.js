const { query, transaction } = require('../config/database')

class TransactionController {
  // POST /api/transactions
  static async createTransaction(req, res) {
    try {
      const { customerId, items, paymentMethod = 'balance', notes, eventId } = req.body
      const organizationId = req.user.organizationId
      const operatorId = req.user.id

      const result = await transaction(async (client) => {
        // Verify customer exists and has sufficient balance
        const customerResult = await client.query(
          'SELECT * FROM customers WHERE id = $1 AND organization_id = $2 AND is_active = true',
          [customerId, organizationId]
        )

        if (customerResult.rows.length === 0) {
          throw new Error('Cliente no encontrado o inactivo')
        }

        const customer = customerResult.rows[0]

        // Calculate total amount and verify products
        let totalAmount = 0
        const validatedItems = []

        for (const item of items) {
          const productResult = await client.query(
            'SELECT * FROM products WHERE id = $1 AND organization_id = $2 AND is_available = true',
            [item.productId, organizationId]
          )

          if (productResult.rows.length === 0) {
            throw new Error(`Producto no encontrado: ${item.productId}`)
          }

          const product = productResult.rows[0]

          if (product.stock_quantity < item.quantity) {
            throw new Error(`Stock insuficiente para ${product.name}. Stock disponible: ${product.stock_quantity}`)
          }

          const itemTotal = parseFloat(product.price) * parseInt(item.quantity)
          totalAmount += itemTotal

          validatedItems.push({
            productId: product.id,
            quantity: parseInt(item.quantity),
            unitPrice: parseFloat(product.price),
            totalPrice: itemTotal
          })
        }

        // Check if customer has sufficient balance for purchase
        if (paymentMethod === 'balance' && customer.current_balance < totalAmount) {
          throw new Error(`Saldo insuficiente. Saldo actual: €${customer.current_balance.toFixed(2)}, Requerido: €${totalAmount.toFixed(2)}`)
        }

        // Create transaction
        const transactionResult = await client.query(
          `INSERT INTO transactions (organization_id, customer_id, operator_id, event_id, transaction_type, total_amount, payment_method, notes)
           VALUES ($1, $2, $3, $4, 'purchase', $5, $6, $7)
           RETURNING *`,
          [organizationId, customerId, operatorId, eventId, totalAmount, paymentMethod, notes]
        )

        const newTransaction = transactionResult.rows[0]

        // Create transaction items
        for (const item of validatedItems) {
          await client.query(
            `INSERT INTO transaction_items (transaction_id, product_id, quantity, unit_price, total_price)
             VALUES ($1, $2, $3, $4, $5)`,
            [newTransaction.id, item.productId, item.quantity, item.unitPrice, item.totalPrice]
          )
        }

        // Get updated customer balance
        const updatedCustomer = await client.query(
          'SELECT current_balance FROM customers WHERE id = $1',
          [customerId]
        )

        return {
          transaction: newTransaction,
          items: validatedItems,
          newBalance: parseFloat(updatedCustomer.rows[0].current_balance)
        }
      })

      res.status(201).json({
        success: true,
        message: 'Transacción creada exitosamente',
        data: result
      })
    } catch (error) {
      console.error('Create transaction error:', error)
      res.status(400).json({
        success: false,
        message: error.message || 'Error interno del servidor'
      })
    }
  }

  // GET /api/transactions/stats/daily
  static async getDailyStats(req, res) {
    try {
      const { date } = req.query
      const organizationId = req.user.organizationId
      const targetDate = date || new Date().toISOString().split('T')[0]

      const result = await query(
        `SELECT 
           COUNT(CASE WHEN transaction_type = 'purchase' THEN 1 END) as total_sales,
           COALESCE(SUM(CASE WHEN transaction_type = 'purchase' THEN total_amount ELSE 0 END), 0) as total_revenue,
           COUNT(DISTINCT customer_id) as unique_customers
         FROM transactions 
         WHERE organization_id = $1 AND DATE(created_at) = $2`,
        [organizationId, targetDate]
      )

      const stats = result.rows[0]

      res.json({
        success: true,
        data: {
          stats: {
            date: targetDate,
            totalSales: parseInt(stats.total_sales),
            totalRevenue: parseFloat(stats.total_revenue),
            uniqueCustomers: parseInt(stats.unique_customers)
          }
        }
      })
    } catch (error) {
      console.error('Get daily stats error:', error)
      res.status(500).json({
        success: false,
        message: 'Error interno del servidor'
      })
    }
  }
}

module.exports = TransactionController
