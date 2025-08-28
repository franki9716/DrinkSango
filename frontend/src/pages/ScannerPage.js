import React, { useState, useEffect } from 'react'
import { Html5QrcodeScanner } from 'html5-qrcode'
import { Scan, User, ShoppingCart, Euro, LogOut, Settings } from 'lucide-react'
import toast from 'react-hot-toast'
import { useAuthContext } from '../hooks/AuthContext'
import { customerAPI, productAPI, transactionAPI } from '../services/api'
import ProductGrid from '../components/ProductGrid'
import CustomerInfo from '../components/CustomerInfo'
import LoadingScreen from '../components/LoadingScreen'

const ScannerPage = () => {
  const { user, logout, isAdmin } = useAuthContext()
  const [scannerActive, setScannerActive] = useState(false)
  const [customer, setCustomer] = useState(null)
  const [products, setProducts] = useState([])
  const [cart, setCart] = useState([])
  const [loading, setLoading] = useState(false)
  const [scanner, setScanner] = useState(null)

  // Load products on component mount
  useEffect(() => {
    loadProducts()
  }, [])

  // Initialize QR Scanner
  useEffect(() => {
    if (scannerActive) {
      initializeScanner()
    } else {
      cleanupScanner()
    }

    return () => cleanupScanner()
  }, [scannerActive])

  const loadProducts = async () => {
    try {
      const response = await productAPI.getProducts({ isAvailable: true })
      setProducts(response.data.data.products)
    } catch (error) {
      toast.error('Error al cargar productos')
    }
  }

  const initializeScanner = () => {
    const qrScanner = new Html5QrcodeScanner(
      'qr-reader',
      { 
        fps: 10,
        qrbox: { width: 250, height: 250 },
        aspectRatio: 1.7777778,
        showTorchButtonIfSupported: true,
      },
      false
    )

    qrScanner.render(onScanSuccess, onScanError)
    setScanner(qrScanner)
  }

  const cleanupScanner = () => {
    if (scanner) {
      scanner.clear().catch(console.error)
    }
  }

  const onScanSuccess = async (decodedText) => {
    try {
      setLoading(true)
      setScannerActive(false)
      
      const response = await customerAPI.getCustomerByQR(decodedText)
      setCustomer(response.data.data.customer)
      setCart([]) // Clear cart when new customer is scanned
      
      toast.success(`Cliente: ${response.data.data.customer.fullName}`)
    } catch (error) {
      const message = error.response?.data?.message || 'Cliente no encontrado'
      toast.error(message)
      setScannerActive(true) // Keep scanning if error
    } finally {
      setLoading(false)
    }
  }

  const onScanError = (error) => {
    // Silent error handling - QR scanning produces many errors naturally
  }

  const addToCart = (product, quantity = 1) => {
    const existingItem = cart.find(item => item.id === product.id)
    
    if (existingItem) {
      setCart(cart.map(item =>
        item.id === product.id
          ? { ...item, quantity: item.quantity + quantity }
          : item
      ))
    } else {
      setCart([...cart, { ...product, quantity }])
    }
    
    toast.success(`${product.name} agregado al carrito`)
  }

  const removeFromCart = (productId) => {
    setCart(cart.filter(item => item.id !== productId))
  }

  const updateCartQuantity = (productId, quantity) => {
    if (quantity <= 0) {
      removeFromCart(productId)
    } else {
      setCart(cart.map(item =>
        item.id === productId
          ? { ...item, quantity }
          : item
      ))
    }
  }

  const getTotalAmount = () => {
    return cart.reduce((total, item) => total + (item.price * item.quantity), 0)
  }

  const processTransaction = async () => {
    if (!customer || cart.length === 0) return

    const totalAmount = getTotalAmount()
    
    if (customer.currentBalance < totalAmount) {
      toast.error('Saldo insuficiente')
      return
    }

    try {
      setLoading(true)
      
      const transactionData = {
        customerId: customer.id,
        items: cart.map(item => ({
          productId: item.id,
          quantity: item.quantity
        })),
        paymentMethod: 'balance'
      }

      await transactionAPI.createTransaction(transactionData)
      
      // Update customer balance
      const newBalance = customer.currentBalance - totalAmount
      setCustomer({ ...customer, currentBalance: newBalance })
      
      // Clear cart
      setCart([])
      
      toast.success('¡Venta procesada exitosamente!')
    } catch (error) {
      const message = error.response?.data?.message || 'Error al procesar la venta'
      toast.error(message)
    } finally {
      setLoading(false)
    }
  }

  const startNewScan = () => {
    setCustomer(null)
    setCart([])
    setScannerActive(true)
  }

  if (loading && !customer) {
    return <LoadingScreen />
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <div className="flex items-center">
              <h1 className="text-2xl font-bold text-gray-900 mr-4">🍹 SanguApp</h1>
              <span className="text-sm text-gray-500">
                {user?.organization?.name}
              </span>
            </div>
            
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-600">
                {user?.fullName} ({user?.role})
              </span>
              
              {isAdmin && (
                <button
                  onClick={() => window.location.href = '/admin'}
                  className="btn-secondary"
                >
                  <Settings className="w-4 h-4 mr-2" />
                  Admin
                </button>
              )}
              
              <button onClick={logout} className="btn-ghost">
                <LogOut className="w-4 h-4 mr-2" />
                Salir
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Left Column - Scanner & Customer Info */}
          <div className="lg:col-span-1 space-y-6">
            {/* QR Scanner */}
            {scannerActive && (
              <div className="card">
                <div className="p-6">
                  <h2 className="text-lg font-semibold mb-4 flex items-center">
                    <Scan className="w-5 h-5 mr-2" />
                    Escanear Código QR
                  </h2>
                  <div id="qr-reader" className="qr-scanner"></div>
                  <button
                    onClick={() => setScannerActive(false)}
                    className="btn-secondary w-full mt-4"
                  >
                    Cancelar Escáner
                  </button>
                </div>
              </div>
            )}

            {/* Start Scan Button */}
            {!scannerActive && !customer && (
              <div className="card">
                <div className="p-8 text-center">
                  <Scan className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                  <h2 className="text-xl font-semibold text-gray-900 mb-2">
                    Escanear Cliente
                  </h2>
                  <p className="text-gray-600 mb-6">
                    Escanea el código QR del cliente para comenzar
                  </p>
                  <button
                    onClick={() => setScannerActive(true)}
                    className="btn-primary btn-xl"
                  >
                    <Scan className="w-6 h-6 mr-2" />
                    Iniciar Escáner
                  </button>
                </div>
              </div>
            )}

            {/* Customer Information */}
            {customer && <CustomerInfo customer={customer} />}

            {/* Shopping Cart */}
            {cart.length > 0 && (
              <div className="card">
                <div className="p-6">
                  <h3 className="text-lg font-semibold mb-4 flex items-center">
                    <ShoppingCart className="w-5 h-5 mr-2" />
                    Carrito ({cart.length})
                  </h3>
                  
                  <div className="space-y-3">
                    {cart.map(item => (
                      <div key={item.id} className="flex items-center justify-between py-2 border-b">
                        <div className="flex-1">
                          <h4 className="font-medium">{item.name}</h4>
                          <p className="text-sm text-gray-500">€{item.price.toFixed(2)} c/u</p>
                        </div>
                        
                        <div className="flex items-center space-x-2">
                          <button
                            onClick={() => updateCartQuantity(item.id, item.quantity - 1)}
                            className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center"
                          >
                            -
                          </button>
                          <span className="font-medium w-8 text-center">{item.quantity}</span>
                          <button
                            onClick={() => updateCartQuantity(item.id, item.quantity + 1)}
                            className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center"
                          >
                            +
                          </button>
                          <button
                            onClick={() => removeFromCart(item.id)}
                            className="ml-2 text-red-600 hover:text-red-800"
                          >
                            ×
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                  
                  <div className="mt-4 pt-4 border-t">
                    <div className="flex justify-between items-center mb-4">
                      <span className="text-lg font-semibold">Total:</span>
                      <span className="text-xl font-bold text-primary-600">
                        €{getTotalAmount().toFixed(2)}
                      </span>
                    </div>
                    
                    <button
                      onClick={processTransaction}
                      disabled={loading || !customer || getTotalAmount() > customer.currentBalance}
                      className="btn-primary w-full btn-lg"
                    >
                      {loading ? (
                        <div className="flex items-center justify-center">
                          <div className="spinner mr-2" />
                          Procesando...
                        </div>
                      ) : (
                        <div className="flex items-center justify-center">
                          <Euro className="w-5 h-5 mr-2" />
                          Procesar Venta
                        </div>
                      )}
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Right Column - Products */}
          <div className="lg:col-span-2">
            {customer ? (
              <div className="space-y-6">
                <div className="flex justify-between items-center">
                  <h2 className="text-xl font-semibold">Productos Disponibles</h2>
                  <button
                    onClick={startNewScan}
                    className="btn-secondary"
                  >
                    <User className="w-4 h-4 mr-2" />
                    Nuevo Cliente
                  </button>
                </div>
                
                <ProductGrid 
                  products={products}
                  onAddToCart={addToCart}
                  customer={customer}
                  cart={cart}
                />
              </div>
            ) : (
              <div className="card">
                <div className="p-12 text-center">
                  <User className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                  <h3 className="text-xl font-medium text-gray-500 mb-2">
                    Sin cliente seleccionado
                  </h3>
                  <p className="text-gray-400">
                    Escanea un código QR para mostrar los productos
                  </p>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

export default ScannerPage
