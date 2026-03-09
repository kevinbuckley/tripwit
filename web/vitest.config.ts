import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Only run .test.ts files — Playwright .spec.ts files are excluded
    include: ["tests/**/*.test.ts"],
    environment: "node",
  },
});
