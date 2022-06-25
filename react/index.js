import React from 'react'
import { createRoot } from 'react-dom/client'
const App = React.lazy(() => import('./components/App'))

const container = document.getElementById('app')
const root = createRoot(container)

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
