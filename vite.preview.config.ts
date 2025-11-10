import { defineConfig } from "vite";
import type { UserConfig } from "vite";
import baseConfig from "./vite.config";

const base = baseConfig as unknown as UserConfig;

export default defineConfig({
  ...base,
  preview: {
    ...(base.preview ?? {}),
    host: true,
    port: Number(process.env.PORT) || 5173,
    // 允许所有域名访问（Vite 5+）
    allowedHosts: true,
  },
});


