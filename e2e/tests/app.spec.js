const fs = require("fs");
const path = require("path");
const { test, expect } = require("@playwright/test");
const pixelmatchModule = require("pixelmatch");
const { PNG } = require("pngjs");
const { waitForReady, waitForOutputStable } = require("../helpers/wait_for_ready");

const pixelmatch = pixelmatchModule.default || pixelmatchModule;

const rootDir = path.resolve(__dirname, "..", "..");
const baselinesRoot = path.join(rootDir, "e2e", "baselines");
const artifactsRoot = path.join(rootDir, "e2e", "artifacts");
const runId = process.env.E2E_RUN_ID || new Date().toISOString().replace(/[:.]/g, "-");
const updateBaselines = process.env.E2E_UPDATE_BASELINES === "1";

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function scenarioPaths(scenario, step) {
  const baselineDir = path.join(baselinesRoot, scenario);
  const artifactDir = path.join(artifactsRoot, runId, scenario);

  ensureDir(baselineDir);
  ensureDir(artifactDir);

  return {
    baselinePath: path.join(baselineDir, `${step}.png`),
    actualPath: path.join(artifactDir, `${step}.png`),
    diffPath: path.join(artifactDir, `${step}.diff.png`)
  };
}

function comparePngs(actualPath, baselinePath, diffPath) {
  const actualPng = PNG.sync.read(fs.readFileSync(actualPath));
  const baselinePng = PNG.sync.read(fs.readFileSync(baselinePath));

  if (actualPng.width !== baselinePng.width || actualPng.height !== baselinePng.height) {
    throw new Error(
      `Screenshot dimensions differ. actual=${actualPng.width}x${actualPng.height}, baseline=${baselinePng.width}x${baselinePng.height}`
    );
  }

  const diffPng = new PNG({ width: actualPng.width, height: actualPng.height });
  const diffPixels = pixelmatch(
    actualPng.data,
    baselinePng.data,
    diffPng.data,
    actualPng.width,
    actualPng.height,
    {
      threshold: 0.1
    }
  );

  if (diffPixels > 0) {
    fs.writeFileSync(diffPath, PNG.sync.write(diffPng));
  } else if (fs.existsSync(diffPath)) {
    fs.rmSync(diffPath, { force: true });
  }

  return diffPixels;
}

async function captureAndAssert(page, scenario, step, screenshotTarget) {
  const { baselinePath, actualPath, diffPath } = scenarioPaths(scenario, step);
  await screenshotTarget.screenshot({
    path: actualPath,
    animations: "disabled"
  });

  if (updateBaselines || !fs.existsSync(baselinePath)) {
    fs.copyFileSync(actualPath, baselinePath);
    if (fs.existsSync(diffPath)) {
      fs.rmSync(diffPath, { force: true });
    }
    return;
  }

  const diffPixels = comparePngs(actualPath, baselinePath, diffPath);
  expect(
    diffPixels,
    `Visual mismatch for ${scenario}/${step}. See ${path.relative(rootDir, diffPath)}`
  ).toBe(0);
}

test.beforeEach(async ({ page }) => {
  const response = await page.goto("/");
  expect(response && response.ok()).toBeTruthy();
  await waitForReady(page);
});

test("Scenario A: Home loads", async ({ page }) => {
  await captureAndAssert(page, "home_loads", "home_loaded", page);
});

test("Scenario B: Critical chart state", async ({ page }) => {
  await page.locator("#principal-which_plot").getByRole("tab", { name: "Gastos" }).click();
  await page.getByLabel("Millones de USD").check();
  await waitForOutputStable(page, "#principal-plot_gastos");

  await captureAndAssert(page, "critical_chart_state", "after_inputs", page);
});
