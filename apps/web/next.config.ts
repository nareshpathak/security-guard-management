import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@diti365/shared", "@diti365/ui"],
  experimental: {
    optimizePackageImports: ["lucide-react", "@diti365/ui"],
  },
  allowedDevOrigins: ["monkeycode-ai.live", "*.monkeycode-ai.live"],
};

export default nextConfig;
