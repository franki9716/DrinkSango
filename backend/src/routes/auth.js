const express = require('express')
const AuthController = require('../controllers/authController')
const { validationRules, handleValidationErrors } = require('../middleware/validation')

const router = express.Router()

// Auth routes
router.post('/login', validationRules.login, handleValidationErrors, AuthController.login)
router.post('/register', validationRules.register, handleValidationErrors, AuthController.register)
router.get('/profile', AuthController.getProfile)
router.put('/profile', AuthController.updateProfile)
router.post('/change-password', AuthController.changePassword)
router.post('/logout', AuthController.logout)

module.exports = router
