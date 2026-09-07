import {defineConfig} from 'vite';
import tailwindcss from '@tailwindcss/vite';
import {resolve} from 'node:path';


export default defineConfig({
    plugins: [tailwindcss()],
    build: {
        outDir: resolve(import.meta.dirname, 'lib/src/http/public'),
        emptyOutDir: false,
        watch: {
            exclude: 'lib/src/http/public/**',
        },
        rollupOptions: {
            input: {
                app: resolve(import.meta.dirname, 'lib/src/resources/js/app.js'),
                styles: resolve(import.meta.dirname, 'lib/src/resources/css/app.css'),
            },
            output: {
                entryFileNames: (chunkInfo) =>
                    chunkInfo.name === 'app' ? 'js/app.js' : 'js/[name].js',
                chunkFileNames: 'js/[name]-[hash].js',
                assetFileNames: (assetInfo) => {
                    const sourceName = assetInfo.names?.[0] ?? assetInfo.name ?? '';

                    return sourceName.endsWith('.css')
                        ? 'css/app.css'
                        : 'assets/[name]-[hash][extname]';
                },
            },
        },
    },
});
