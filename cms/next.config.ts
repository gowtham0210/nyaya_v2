import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Self-contained server bundle for the Docker image (deploy/staging).
  output: 'standalone',
  cacheComponents: true,
  partialPrefetching: true,
  experimental: {
    // Question files go to the API as uploads of up to 2 MB, plus form overhead.
    serverActions: { bodySizeLimit: '3mb' },
  },
  turbopack: {
    rules: {
      '*.css': {
        loaders: ['@tailwindcss/turbopack'],
        as: '*.css',
      },
    },
  },
  async redirects() {
    return [{ source: '/', destination: '/questions', permanent: false }];
  },
};

export default nextConfig;
