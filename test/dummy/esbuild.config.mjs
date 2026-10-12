import { execSync } from "node:child_process"
import { mkdirSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import * as esbuild from "esbuild"

const root = path.dirname(fileURLToPath(import.meta.url))
const flatPack = execSync("bundle show flat_pack", { cwd: root, encoding: "utf8" }).trim()
const javascript = path.join(flatPack, "app/javascript/flat_pack")

mkdirSync(path.join(root, "app/assets/builds"), { recursive: true })

await esbuild.build({
  absWorkingDir: root,
  entryPoints: ["app/javascript/mcp_ui_widgets.js"],
  bundle: true,
  format: "iife",
  platform: "browser",
  target: "es2020",
  outfile: "app/assets/builds/mcp_ui_widgets.js",
  nodePaths: [path.join(root, "node_modules")],
  alias: {
    flat_pack: javascript,
    "controllers/flat_pack": path.join(javascript, "controllers")
  }
})
