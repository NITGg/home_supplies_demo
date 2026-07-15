import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    unoptimized: true,
    remotePatterns: [
      {
        protocol: "https",
        hostname: "res.cloudinary.com",
        pathname: "/**",
      },
      {
        protocol: "http",
        hostname: "localhost",
        pathname: "/**",
      },
      {
        protocol: "https",
        hostname: "tawreedat.nitg-eg.com",
        pathname: "/**",
      },
      {
        protocol: "http",
        hostname: "tawreedat.nitg-eg.com",
        pathname: "/**",
      },
      {
        protocol: "https",
        hostname: "academy2022.nitg-eg.com",
        pathname: "/**",
      },
      {
        protocol: "https",
        hostname: "lh3.googleusercontent.com",
        pathname: "/**",
      },
    ],
  },
};

export default nextConfig;
