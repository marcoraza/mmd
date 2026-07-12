import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  images: { unoptimized: true },
  turbopack: {
    root: __dirname,
  },
  // React Compiler: memoização automática.
  // Em Next 16 a flag saiu de `experimental` e virou top-level.
  // Pré-requisito (eslint-plugin-react-compiler) já ativo em eslint.config.mjs.
  reactCompiler: true,
}

export default nextConfig
