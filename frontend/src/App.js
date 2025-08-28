import React from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import { AuthProvider, useAuthContext } from './hooks/AuthContext'

// Pages
import LoginPage from './pages/LoginPage'
import ScannerPage from './pages/ScannerPage'
import AdminPage from './pages/AdminPage'
import LoadingScreen from './components/LoadingScreen'

// Protected Route Component
const ProtectedRoute = ({ children }) => {
  const { isAuthenticated, loading } = useAuthContext()

  if (loading) {
    return <LoadingScreen />
  }

  return isAuthenticated ? children : <Navigate to="/login" replace />
}

// Admin Route Component
const AdminRoute = ({ children }) => {
  const { isAdmin, loading } = useAuthContext()

  if (loading) {
    return <LoadingScreen />
  }

  return isAdmin ? children : <Navigate to="/scanner" replace />
}

function AppContent() {
  const { loading } = useAuthContext()

  if (loading) {
    return <LoadingScreen />
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Router>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/scanner" element={
            <ProtectedRoute>
              <ScannerPage />
            </ProtectedRoute>
          } />
          <Route path="/admin" element={
            <ProtectedRoute>
              <AdminRoute>
                <AdminPage />
              </AdminRoute>
            </ProtectedRoute>
          } />
          <Route path="/" element={<Navigate to="/scanner" replace />} />
          <Route path="*" element={<Navigate to="/scanner" replace />} />
        </Routes>
      </Router>

      {/* Global Toast Notifications */}
      <Toaster
        position="top-center"
        toastOptions={{
          duration: 4000,
          style: {
            background: '#363636',
            color: '#fff',
            borderRadius: '10px',
            fontSize: '16px',
            padding: '16px',
            maxWidth: '500px',
          },
          success: {
            iconTheme: {
              primary: '#10B981',
              secondary: '#fff',
            },
          },
          error: {
            iconTheme: {
              primary: '#EF4444',
              secondary: '#fff',
            },
          },
        }}
      />
    </div>
  )
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  )
}

export default App
