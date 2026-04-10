import { defineConfig } from "vitest/config";
import { resolve } from "node:path";

export default defineConfig({
  resolve: {
    alias: {
      "@server": resolve(__dirname, "src"),
    },
  },
  test: {
    globals: true,
  },
});
