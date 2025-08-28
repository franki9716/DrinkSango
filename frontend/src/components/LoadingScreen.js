import React from 'react'
import { Loader2 } from 'lucide-react'

const LoadingScreen = () => {
  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-500 via-primary-600 to-primary-700 flex items-center justify-center">
      <div className="text-center">
        <div className="mb-8">
          <h1 className="text-6xl font-bold text-white mb-2">🍹</h1>
          <h2 className="text-3xl font-bold text-white mb-2">SanguApp</h2>
          <p className="text-primary-100 text-lg">Cargando sistema...</p>
        </div>
        
        <div className="flex items-center justify-center">
          <Loader2 className="w-8 h-8 text-white animate-spin" />
        </div>
      </div>
    </div>
  )
}

export default LoadingScreen
