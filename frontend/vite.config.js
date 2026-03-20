import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: './',           // Relative paths for Electron's file:// loading
  build: {
    outDir: 'dist',
  },
  server: {
    port: 5173,
  },
})
