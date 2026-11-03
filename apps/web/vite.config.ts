import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const api = loadEnv(mode, '.', '').VITE_API_BASE || 'http://127.0.0.1:8000'
  return {
    plugins: [react()],
    server: {
      port: 5173,
      // /sim is proxied so the 3D iframe is same-origin with the app
      proxy: { '/sim': api },
    },
  }
})
