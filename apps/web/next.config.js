/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ['@relix/core'],
  experimental: {
    typedRoutes: true,
  },
};

module.exports = nextConfig;
