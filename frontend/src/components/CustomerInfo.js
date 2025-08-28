import React from 'react'
import { User, CreditCard, Euro } from 'lucide-react'

const CustomerInfo = ({ customer }) => {
  const balanceColor = customer.currentBalance > 20 
    ? 'text-secondary-600' 
    : customer.currentBalance > 5 
    ? 'text-accent-600' 
    : 'text-red-600'

  return (
    <div className="card">
      <div className="p-6">
        <h3 className="text-lg font-semibold mb-4 flex items-center">
          <User className="w-5 h-5 mr-2" />
          Información del Cliente
        </h3>
        
        <div className="space-y-4">
          <div>
            <h4 className="font-semibold text-gray-900 text-lg">
              {customer.fullName}
            </h4>
            {customer.email && (
              <p className="text-sm text-gray-600">{customer.email}</p>
            )}
          </div>
          
          <div className="flex items-center justify-between py-3 px-4 bg-gray-50 rounded-lg">
            <div className="flex items-center">
              <CreditCard className="w-5 h-5 text-gray-500 mr-2" />
              <span className="font-medium">Saldo Disponible:</span>
            </div>
            <span className={`text-xl font-bold ${balanceColor}`}>
              €{customer.currentBalance.toFixed(2)}
            </span>
          </div>
          
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div className="text-center p-3 bg-blue-50 rounded-lg">
              <div className="font-semibold text-blue-800">Total Gastado</div>
              <div className="text-blue-600 font-medium">
                €{customer.totalSpent.toFixed(2)}
              </div>
            </div>
            
            <div className="text-center p-3 bg-purple-50 rounded-lg">
              <div className="font-semibold text-purple-800">QR Code</div>
              <div className="text-purple-600 font-medium text-xs">
                {customer.qrCode}
              </div>
            </div>
          </div>
          
          {customer.event && (
            <div className="mt-3 p-2 bg-green-50 rounded text-center">
              <span className="text-green-800 font-medium text-sm">
                📅 {customer.event.name}
              </span>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default CustomerInfo
