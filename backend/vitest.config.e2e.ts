import { defineConfig } from 'vitest/config';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    globals: true,
    root: './',
    include: ['**/*.e2e-spec.ts'],
    // Each file starts its own in-memory database and runs every migration;
    // with several files in parallel that can take a while on a busy machine.
    // Some tests start their own app, so they get the same time.
    hookTimeout: 30_000,
    testTimeout: 30_000,
  },
});
