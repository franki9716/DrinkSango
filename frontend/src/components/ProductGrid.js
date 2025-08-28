import React from 'react'
import { Plus, AlertTriangle, Package } from 'lucide-react'

const ProductGrid = ({ products, onAddToCart, customer, cart }) => {
  const getProductInCart = (productId) => {
    return cart.find(item => item.id === productId)
  }

  const canAfford = (price) => {
    return customer.currentBalance >= price
  }

  const getStockBadge = (product) => {
    if (product.stockQuantity === 0) {
      return <span className="badge-danger">Sin Stock</span>
    }
    if (product.lowStock) {
      return <span className="badge-warning">Stock Bajo</span>
    }
    return null
  }

  const getCategoryIcon = (category) => {
    switch (category) {
      case 'bebida':
        return '🍺'
      case 'comida':
        return '🍽️'
      case 'merchandising':
        return '🎁'
      default:
        return '📦'
    }
  }

  const getCategoryColor = (category) => {
    switch (category) {
      case 'bebida':
        return 'bg-blue-100 text-blue-800'
      case 'comida':
        return 'bg-green-100 text-green-800'
      case 'merchandising':
        return 'bg-purple-100 text-purple-800'
      default:
        return 'bg-gray-100 text-gray-800'
    }
  }

  if (products.length === 0) {
    return (
      <div className="card">
        <div className="p-8 text-center">
          <Package className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-500 mb-2">
            No hay productos disponibles
          </h3>
          <p className="text-gray-400">
            Contacta al administrador para agregar productos
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
      {products.map(product => {
        const cartItem = getProductInCart(product.id)
        const affordable = canAfford(product.price)
        const inStock = product.stockQuantity > 0
        const canAdd = affordable && inStock

        return (
          <div
            key={product.id}
            className={`card-hover transition-all duration-200 ${
              !canAdd ? 'opacity-60' : 'hover:shadow-lg'
            }`}
          >
            <div className="p-4">
              {/* Product Image/Icon */}
              <div className="text-center mb-3">
                {product.imageUrl ? (
                  <img
                    src={product.imageUrl}
                    alt={product.name}
                    className="w-16 h-16 mx-auto rounded-lg object-cover"
                  />
                ) : (
                  <div className="w-16 h-16 mx-auto bg-gray-100 rounded-lg flex items-center justify-center text-2xl">
                    {getCategoryIcon(product.category)}
                  </div>
                )}
              </div>

              {/* Product Info */}
              <div className="text-center space-y-2">
                <h3 className="font-semibold text-gray-900 text-sm leading-tight">
                  {product.name}
                </h3>
                
                {product.description && (
                  <p className="text-xs text-gray-500 line-clamp-2">
                    {product.description}
                  </p>
                )}

                {/* Category Badge */}
                <span className={`inline-block px-2 py-1 rounded-full text-xs font-medium ${getCategoryColor(product.category)}`}>
                  {product.category}
                </span>

                {/* Price */}
                <div className="text-lg font-bold text-primary-600">
                  €{product.price.toFixed(2)}
                </div>

                {/* Stock Badge */}
                {getStockBadge(product) && (
                  <div className="flex justify-center">
                    {getStockBadge(product)}
                  </div>
                )}

                {/* Affordability Warning */}
                {!affordable && inStock && (
                  <div className="flex items-center justify-center text-red-600 text-xs">
                    <AlertTriangle className="w-3 h-3 mr-1" />
                    Saldo insuficiente
                  </div>
                )}
              </div>

              {/* Add to Cart Button */}
              <div className="mt-4 space-y-2">
                {cartItem && (
                  <div className="text-center text-sm text-primary-600 font-medium">
                    En carrito: {cartItem.quantity}
                  </div>
                )}
                
                <button
                  onClick={() => onAddToCart(product)}
                  disabled={!canAdd}
                  className={`w-full btn ${
                    canAdd
                      ? 'btn-primary hover:scale-105'
                      : 'bg-gray-200 text-gray-400 cursor-not-allowed'
                  }`}
                >
                  <Plus className="w-4 h-4 mr-1" />
                  Agregar
                </button>
              </div>

              {/* Stock Quantity (for operators to see) */}
              <div className="mt-2 text-center text-xs text-gray-400">
                Stock: {product.stockQuantity} unidades
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}

export default ProductGrid
