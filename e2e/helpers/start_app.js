const { spawn } = require("child_process");

const port = process.env.APP_PORT || "3838";
const child = spawn(
  "R",
  ["-q", "-e", `shiny::runApp('monitor/app', host='127.0.0.1', port=${port})`],
  {
    stdio: "inherit",
    env: {
      ...process.env,
      APP_TEST_MODE: process.env.APP_TEST_MODE || "1"
    }
  }
);

const stopChild = (signal) => {
  if (!child.killed) {
    child.kill(signal);
  }
};

process.on("SIGINT", () => stopChild("SIGINT"));
process.on("SIGTERM", () => stopChild("SIGTERM"));

child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }

  process.exit(code == null ? 1 : code);
});
