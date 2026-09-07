import { defineConfig } from 'vite'

export default defineConfig({
  root: '.',
  publicDir: 'public',
  build: {
    outDir: 'dist',
    rollupOptions: {
      input: {
        main: 'index.html',
        privacy: 'privacypolicy.html',
        deletion: 'accountdeletion.html',
      }
    }
  },
  server: {
    port: 3000,
    open: true
  }
})
