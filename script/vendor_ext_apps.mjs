import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const work = "/tmp/rs-mcp-ui-ext-apps";
const version = "2.0.3";
const outfile = join(root, "app/javascript/recording_studio_mcp_ui/vendor/ext-apps.iife.js");

mkdirSync(work, { recursive: true });
writeFileSync(join(work, "package.json"), JSON.stringify({ private: true }, null, 2));

const npm = spawnSync(
  "npm",
  ["install", "--no-fund", "--no-audit", `@modelcontextprotocol/ext-apps@${version}`, "esbuild@0.25.12"],
  { cwd: work, stdio: "inherit" }
);
if (npm.status !== 0) process.exit(npm.status ?? 1);

writeFileSync(
  join(work, "entry.mjs"),
  'export { App, PostMessageTransport } from "@modelcontextprotocol/ext-apps/app-with-deps";\n'
);

const esbuild = spawnSync(
  join(work, "node_modules/.bin/esbuild"),
  [
    "entry.mjs",
    "--bundle",
    "--format=iife",
    "--global-name=McpApps",
    "--legal-comments=none",
    `--outfile=${outfile}`
  ],
  { cwd: work, stdio: "inherit" }
);
if (esbuild.status !== 0) process.exit(esbuild.status ?? 1);
