const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

test("host bridge speaks MCP Apps JSON-RPC to a mock parent", async () => {
  const messages = [];
  const listeners = [];
  const windowLike = {
    parent: {
      postMessage(message) {
        messages.push(message);
        if (message.method === "ui/initialize") {
          listeners.forEach((listener) => listener({
            data: { jsonrpc: "2.0", id: message.id, result: { protocolVersion: "2025-06-18" } }
          }));
        }
        if (message.method === "tools/call") {
          listeners.forEach((listener) => listener({
            data: { jsonrpc: "2.0", id: message.id, result: { structuredContent: { ok: true, data: { title: "Saved" } } } }
          }));
        }
      }
    },
    addEventListener(name, fn) {
      if (name === "message") listeners.push(fn);
    },
    document: { readyState: "complete", getElementById() { return null; }, addEventListener() {} }
  };
  windowLike.window = windowLike;

  const source = fs.readFileSync(
    path.join(__dirname, "../../app/javascript/recording_studio_mcp_ui/host_bridge.js"),
    "utf8"
  );
  vm.runInContext(source, vm.createContext(windowLike));

  const result = await windowLike.McpAppsHost.initialize({ name: "widget" });
  assert.equal(result.protocolVersion, "2025-06-18");
  assert.equal(messages[0].method, "ui/initialize");
  assert.equal(messages[1].method, "ui/notifications/initialized");

  const tool = await windowLike.McpAppsHost.callTool("save", { id: 1 });
  assert.equal(tool.structuredContent.data.title, "Saved");
});
