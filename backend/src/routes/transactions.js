const express = require('express')
const TransactionController = require('../controllers/transactionController')
const { validationRules, handleValidationErrors } = require('../middleware/validation')

const router = express.Router()

// Transaction routes
router.post('/', validationRules.createTransaction, handleValidationErrors, TransactionController.createTransaction)
router.get('/stats/daily', TransactionController.getDailyStats)

module.exports = router
