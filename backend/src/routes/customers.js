const express = require('express')
const CustomerController = require('../controllers/customerController')
const { validationRules, handleValidationErrors } = require('../middleware/validation')
const { requireRole, requireSameOrganization } = require('../middleware/auth')

const router = express.Router()

// Customer routes
router.get('/', CustomerController.getCustomers)
router.get('/:id', CustomerController.getCustomer)
router.get('/qr/:qrCode', CustomerController.getCustomerByQR)
router.post('/', validationRules.createCustomer, handleValidationErrors, requireRole('admin', 'superadmin'), CustomerController.createCustomer)
router.put('/:id', requireRole('admin', 'superadmin'), CustomerController.updateCustomer)
router.post('/:id/top-up', CustomerController.topUpBalance)
router.delete('/:id', requireRole('admin', 'superadmin'), CustomerController.deleteCustomer)

module.exports = router
