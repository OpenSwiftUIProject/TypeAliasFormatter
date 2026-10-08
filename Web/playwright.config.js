import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  timeout: 60_000,
  expect: { timeout: 10_000 },
  workers: 1,
  use: { baseURL: "http://127.0.0.1:4176/TypeAliasFormatter/", viewport: { width: 1280, height: 800 } },
  webServer: {
    command: "npm run preview -- --port 4176 --strictPort",
    url: "http://127.0.0.1:4176/TypeAliasFormatter/",
    reuseExistingServer: !process.env.CI,
  },
});
