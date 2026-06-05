var _a;
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
export default defineConfig({
    plugins: [react()],
    build: {
        chunkSizeWarningLimit: 800,
    },
    server: {
        port: 5174,
        proxy: {
            '/api': {
                target: (_a = process.env.VITE_DEV_API_PROXY_TARGET) !== null && _a !== void 0 ? _a : 'http://localhost:3100',
                changeOrigin: true,
            },
        },
    },
});
