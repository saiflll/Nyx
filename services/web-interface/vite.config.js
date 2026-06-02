import { sveltekit } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://nginx:80',
        changeOrigin: true,
      }
    }
  }
});
