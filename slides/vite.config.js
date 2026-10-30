import { resolve } from 'node:path';
import { defineConfig } from 'vite';

// Trois entrées : la présentation (index.html), la fenêtre de notes orateur
// (notes.html, ouverte par la touche N) et la planche du guide de style
// (styleguide.html), qui n'est pas incluse dans la présentation.
export default defineConfig({
  base: './',
  server: { host: '127.0.0.1', port: 5173 },
  preview: { host: '127.0.0.1', port: 4173 },
  build: {
    outDir: 'dist',
    chunkSizeWarningLimit: 1500,
    rollupOptions: {
      input: {
        main: resolve(import.meta.dirname, 'index.html'),
        styleguide: resolve(import.meta.dirname, 'styleguide.html'),
        notes: resolve(import.meta.dirname, 'notes.html'),
      },
    },
  },
});
