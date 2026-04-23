import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  basePath: "/nmd",
  images: { unoptimized: true },
  turbopack: {
    root: __dirname,
  },
};

export default nextConfig;
