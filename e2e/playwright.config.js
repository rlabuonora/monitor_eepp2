const { defineConfig } = require("@playwright/test");
const path = require("path");

const rootDir = path.resolve(__dirname, "..");
const artifactsRoot = path.join(rootDir, "e2e", "artifacts");

module.exports = defineConfig({
  testDir: path.join(__dirname, "tests"),
  outputDir: path.join(artifactsRoot, ".playwright"),
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 90000,
  expect: {
    timeout: 10000
  },
  use: {
    baseURL: "http://127.0.0.1:3838",
    headless: true,
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
    reducedMotion: "reduce",
    trace: "off",
    video: "off",
    screenshot: "off"
  },
  webServer: {
    command: "node e2e/helpers/start_app.js",
    url: "http://127.0.0.1:3838",
    cwd: rootDir,
    timeout: 120000,
    reuseExistingServer: false,
    stdout: "pipe",
    stderr: "pipe",
    env: {
      ...process.env,
      APP_TEST_MODE: "1",
      APP_PORT: "3838"
    }
  }
});
