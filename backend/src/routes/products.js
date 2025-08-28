const express = require('express')
const ProductController = require('../controllers/productController')
const { validationRules, handleValidationErrors } = require('../middleware/validation')
const { requireRole } = require('../middleware/auth')

const router = express.Router()

// Product routes
router.get('/', ProductController.getProducts)
router.get('/:id', ProductController.getProduct)
router.post('/', validationRules.createProduct, handleValidationErrors, requireRole('admin', 'superadmin'), ProductController.createProduct)
router.put('/:id', requireRole('admin', 'superadmin'), ProductController.updateProduct)
router.delete('/:id', requireRole('admin', 'superadmin'), ProductController.deleteProduct)

module.exports = router
