import React, { useState, useEffect } from 'react'
import { 
  Users, 
  Package, 
  BarChart3, 
  Settings, 
  LogOut,
  Plus,
  Euro,
  TrendingUp,
  Calendar,
  Scan
} from 'lucide-react'
import { useAuthContext } from '../hooks/AuthContext'
import { productAPI, customerAPI, transactionAPI } from '../services/api'
import toast from 'react-hot-toast'

const AdminPage = () => {
  const { user, logout } = useAuthContext()
  const [activeTab, setActiveTab] = useState('dashboard')
  const [stats, setStats] = useState({
    totalCustomers: 0,
    totalProducts: 0,
    dailyRevenue: 0,
    dailySales: 0
  })
  const [products, setProducts] = useState([])
  const [customers, setCustomers] = useState([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    loadDashboardData()
  }, [])

  const loadDashboardData = async () => {
    try {
      setLoading(true)
      
      const [productsRes, customersRes, statsRes] = await Promise.all([
        productAPI.getProducts({ limit: 10 }),
        customerAPI.getCustomers({ limit: 10 }),
        transactionAPI.getDailyStats()
      ])

      setProducts(productsRes.data.data.products)
      setCustomers(customersRes.data.data.customers)
      
      const dailyStats = statsRes.data.data.stats
      setStats({
        totalCustomers: customersRes.data.data.pagination.total,
        totalProducts: productsRes.data.data.pagination.total,
        dailyRevenue: dailyStats.totalRevenue,
        dailySales: dailyStats.totalSales
      })
    } catch (error) {
      toast.error('Error al cargar datos del dashboard')
    } finally {
      setLoading(false)
    }
  }

  const tabs = [
    { id: 'dashboard', name: 'Dashboard', icon: BarChart3 },
    { id: 'products', name: 'Productos', icon: Package },
    { id: 'customers', name: 'Clientes', icon: Users },
    { id: 'settings', name: 'Configuración', icon: Settings }
  ]

  const DashboardTab = () => (
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="card">
          <div className="p-6">
            <div className="flex items-center">
              <div className="p-2 bg-blue-100 rounded-lg">
                <Euro className="w-6 h-6 text-blue-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Ventas Hoy</p>
                <p className="text-2xl font-semibold text-gray-900">
                  €{stats.dailyRevenue.toFixed(2)}
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="p-6">
            <div className="flex items-center">
              <div className="p-2 bg-green-100 rounded-lg">
                <TrendingUp className="w-6 h-6 text-green-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Transacciones</p>
                <p className="text-2xl font-semibold text-gray-900">
                  {stats.dailySales}
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="p-6">
            <div className="flex items-center">
              <div className="p-2 bg-purple-100 rounded-lg">
                <Users className="w-6 h-6 text-purple-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Clientes</p>
                <p className="text-2xl font-semibold text-gray-900">
                  {stats.totalCustomers}
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="p-6">
            <div className="flex items-center">
              <div className="p-2 bg-orange-100 rounded-lg">
                <Package className="w-6 h-6 text-orange-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Productos</p>
                <p className="text-2xl font-semibold text-gray-900">
                  {stats.totalProducts}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="card">
        <div className="p-6">
          <h3 className="text-lg font-semibold mb-4">Acciones Rápidas</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <button
              onClick={() => setActiveTab('products')}
              className="btn-primary flex items-center justify-center p-4"
            >
              <Plus className="w-5 h-5 mr-2" />
              Agregar Producto
            </button>
            
            <button
              onClick={() => setActiveTab('customers')}
              className="btn-secondary flex items-center justify-center p-4"
            >
              <Users className="w-5 h-5 mr-2" />
              Gestionar Clientes
            </button>
            
            <button
              onClick={() => window.location.href = '/scanner'}
              className="btn-success flex items-center justify-center p-4"
            >
              <Scan className="w-5 h-5 mr-2" />
              Ir al Escáner
            </button>
          </div>
        </div>
      </div>

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card">
          <div className="p-6">
            <h3 className="text-lg font-semibold mb-4">Productos Recientes</h3>
            <div className="space-y-3">
              {products.slice(0, 5).map(product => (
                <div key={product.id} className="flex items-center justify-between py-2">
                  <div>
                    <p className="font-medium">{product.name}</p>
                    <p className="text-sm text-gray-500">€{product.price.toFixed(2)}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium">Stock: {product.stockQuantity}</p>
                    {product.lowStock && (
                      <span className="badge-warning text-xs">Stock Bajo</span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="card">
          <div className="p-6">
            <h3 className="text-lg font-semibold mb-4">Clientes Recientes</h3>
            <div className="space-y-3">
              {customers.slice(0, 5).map(customer => (
                <div key={customer.id} className="flex items-center justify-between py-2">
                  <div>
                    <p className="font-medium">{customer.fullName}</p>
                    <p className="text-sm text-gray-500">{customer.qrCode}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium">€{customer.currentBalance.toFixed(2)}</p>
                    <p className="text-xs text-gray-500">
                      Gastado: €{customer.totalSpent.toFixed(2)}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )

  const ProductsTab = () => (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold">Gestión de Productos</h2>
        <button className="btn-primary">
          <Plus className="w-4 h-4 mr-2" />
          Nuevo Producto
        </button>
      </div>

      <div className="card">
        <div className="p-6">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Producto</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Categoría</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Precio</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Stock</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {products.map(product => (
                  <tr key={product.id}>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div>
                        <div className="text-sm font-medium text-gray-900">{product.name}</div>
                        {product.description && (
                          <div className="text-sm text-gray-500">{product.description}</div>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="badge-info">{product.category}</span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      €{product.price.toFixed(2)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{product.stockQuantity}</div>
                      {product.lowStock && (
                        <span className="badge-warning">Bajo</span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {product.isAvailable ? (
                        <span className="badge-success">Disponible</span>
                      ) : (
                        <span className="badge-danger">No Disponible</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  )

  const CustomersTab = () => (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold">Gestión de Clientes</h2>
        <button className="btn-primary">
          <Plus className="w-4 h-4 mr-2" />
          Nuevo Cliente
        </button>
      </div>

      <div className="card">
        <div className="p-6">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Cliente</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">QR Code</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Saldo Actual</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Total Gastado</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {customers.map(customer => (
                  <tr key={customer.id}>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div>
                        <div className="text-sm font-medium text-gray-900">{customer.fullName}</div>
                        {customer.email && (
                          <div className="text-sm text-gray-500">{customer.email}</div>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {customer.qrCode}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">
                        €{customer.currentBalance.toFixed(2)}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      €{customer.totalSpent.toFixed(2)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {customer.isActive ? (
                        <span className="badge-success">Activo</span>
                      ) : (
                        <span className="badge-danger">Inactivo</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  )

  const SettingsTab = () => (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Configuración</h2>
      
      <div className="card">
        <div className="p-6">
          <h3 className="text-lg font-semibold mb-4">Información de la Organización</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Nombre de la Organización
              </label>
              <input
                type="text"
                value={user?.organization?.name || ''}
                className="input"
                disabled
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Identificador
              </label>
              <input
                type="text"
                value={user?.organization?.slug || ''}
                className="input"
                disabled
              />
            </div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="p-6">
          <h3 className="text-lg font-semibold mb-4">Información del Usuario</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Nombre Completo
              </label>
              <input
                type="text"
                value={user?.fullName || ''}
                className="input"
                disabled
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Email
              </label>
              <input
                type="email"
                value={user?.email || ''}
                className="input"
                disabled
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Rol
              </label>
              <input
                type="text"
                value={user?.role || ''}
                className="input"
                disabled
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  )

  const renderActiveTab = () => {
    switch (activeTab) {
      case 'dashboard':
        return <DashboardTab />
      case 'products':
        return <ProductsTab />
      case 'customers':
        return <CustomersTab />
      case 'settings':
        return <SettingsTab />
      default:
        return <DashboardTab />
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="spinner w-8 h-8 mx-auto mb-4" />
          <p>Cargando panel de administración...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <div className="flex items-center">
              <h1 className="text-2xl font-bold text-gray-900 mr-4">🍹 SanguApp Admin</h1>
              <span className="text-sm text-gray-500">
                {user?.organization?.name}
              </span>
            </div>
            
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-600">
                {user?.fullName} ({user?.role})
              </span>
              
              <button
                onClick={() => window.location.href = '/scanner'}
                className="btn-secondary"
              >
                <Scan className="w-4 h-4 mr-2" />
                Escáner
              </button>
              
              <button onClick={logout} className="btn-ghost">
                <LogOut className="w-4 h-4 mr-2" />
                Salir
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="flex">
          {/* Sidebar Navigation */}
          <div className="w-64 mr-8">
            <nav className="space-y-2">
              {tabs.map(tab => {
                const Icon = tab.icon
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={`w-full flex items-center px-4 py-3 text-left rounded-lg transition-colors ${
                      activeTab === tab.id
                        ? 'bg-primary-100 text-primary-700 font-medium'
                        : 'text-gray-700 hover:bg-gray-100'
                    }`}
                  >
                    <Icon className="w-5 h-5 mr-3" />
                    {tab.name}
                  </button>
                )
              })}
            </nav>
          </div>

          {/* Main Content */}
          <div className="flex-1">
            {renderActiveTab()}
          </div>
        </div>
      </div>
    </div>
  )
}

export default AdminPage
