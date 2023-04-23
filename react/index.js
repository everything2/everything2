import React from 'react'
import './assets/favicon.ico'

import { createRoot } from 'react-dom/client'
const E2ReactRoot = React.lazy(() => import('./components/E2ReactRoot'))


const container = document.getElementById('e2-react-root')
const root = createRoot(container)

root.render(
  <React.StrictMode>
    <E2ReactRoot />
  </React.StrictMode>
)
