async function waitForWidgetRendered(page, outputSelector, timeout) {
  await page.waitForFunction((selector) => {
    const root = document.querySelector(selector);
    if (!root) {
      return false;
    }

    const svg = root.querySelector("svg");
    if (!svg) {
      return false;
    }

    const rect = svg.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) {
      return false;
    }

    const graphicNodes = svg.querySelectorAll("rect, path, polygon, line, circle");
    return graphicNodes.length > 0;
  }, outputSelector, {
    timeout
  });
}

async function waitForReady(page, options = {}) {
  const timeout = options.timeout || 30000;
  const outputSelector = options.outputSelector || "#principal-plot_resultado";

  await page.waitForSelector("#app-ready[data-ready='1']", {
    state: "attached",
    timeout
  });
  await page.waitForSelector(outputSelector, {
    state: "visible",
    timeout
  });
  await waitForWidgetRendered(page, outputSelector, timeout);

  await page.addStyleTag({
    content: `
      *, *::before, *::after {
        animation: none !important;
        transition: none !important;
        caret-color: transparent !important;
      }
    `
  });

  await page.evaluate(() => new Promise((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(resolve));
  }));
  await page.waitForTimeout(300);
}

async function waitForOutputStable(page, selector, delay = 500) {
  await page.waitForSelector(selector, {
    state: "visible",
    timeout: 30000
  });
  await waitForWidgetRendered(page, selector, 30000);
  await page.evaluate(() => new Promise((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(resolve));
  }));
  await page.waitForTimeout(delay);
}

module.exports = {
  waitForReady,
  waitForOutputStable
};
