const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function loadRuntime(windowLike) {
  const files = [
    "runtime.js",
    "controllers/editor_controller.js",
    "boot.js"
  ];
  const context = vm.createContext(windowLike);
  files.forEach((file) => {
    const source = fs.readFileSync(
      path.join(__dirname, "../../app/javascript/recording_studio_mcp_ui", file),
      "utf8"
    );
    vm.runInContext(source, context, { filename: file });
  });
  return context;
}

function fakeDocument(config) {
  const listeners = {};
  return {
    readyState: "complete",
    getElementById(id) {
      if (id === "mcp-ui-config") {
        return { textContent: JSON.stringify(config) };
      }
      return null;
    },
    querySelector() { return null; },
    querySelectorAll() { return []; },
    addEventListener(name, fn) {
      listeners[name] = listeners[name] || [];
      listeners[name].push(fn);
    }
  };
}

function windowStub(config) {
  const windowLike = {
    addEventListener() {},
    postMessage() {},
    document: fakeDocument(config)
  };
  windowLike.window = windowLike;
  windowLike.parent = windowLike;
  return windowLike;
}

test("execute rejects unregistered action aliases", async () => {
  const windowLike = windowStub({
    widgetId: "projects.editor",
    actions: ["save"],
    data: { title: "Beach House" }
  });
  const ctx = loadRuntime(windowLike);
  await ctx.mcpUI.start();
  await assert.rejects(() => ctx.mcpUI.execute("destroy", {}), (error) => {
    assert.equal(error.error, "unauthorized_action");
    return true;
  });
});

test("execute uses fallback transport and refreshes data", async () => {
  const windowLike = windowStub({
    widgetId: "projects.editor",
    actions: ["save"],
    data: { title: "Old", revision: 1 }
  });
  const ctx = loadRuntime(windowLike);
  await ctx.mcpUI.start();
  ctx.mcpUI.setFallbackExecutor(async () => ({
    ok: true,
    data: { title: "New", revision: 2 }
  }));
  const result = await ctx.mcpUI.execute("save", { title: "New" });
  assert.equal(result.data.title, "New");
  assert.equal(ctx.mcpUI.data().title, "New");
  assert.equal(ctx.mcpUI.isDirty(), false);
});

test("dirty tracking resets", async () => {
  const windowLike = windowStub({ actions: ["save"], data: { title: "A" } });
  const ctx = loadRuntime(windowLike);
  await ctx.mcpUI.start();
  ctx.mcpUI.markDirty();
  assert.equal(ctx.mcpUI.isDirty(), true);
  ctx.mcpUI.reset();
  assert.equal(ctx.mcpUI.isDirty(), false);
  assert.equal(ctx.mcpUI.data().title, "A");
});

test("execute uses official App.callServerTool when connected", async () => {
  const calls = [];
  const windowLike = windowStub({
    widgetId: "projects.editor",
    version: "1.0.0",
    actions: ["save"],
    data: { title: "Old", revision: 1 }
  });
  windowLike.parent = { distinct: true };
  windowLike.McpApps = {
    App: function App() {
      this.connect = async function () { return this; };
      this.callServerTool = async function (params) {
        calls.push(params);
        return { structuredContent: { ok: true, data: { title: "Saved", revision: 2 } } };
      };
      this.updateModelContext = async function () { return {}; };
    },
    PostMessageTransport: function PostMessageTransport() {}
  };

  const ctx = loadRuntime(windowLike);
  await ctx.mcpUI.start();
  assert.ok(ctx.mcpUI.app());
  const result = await ctx.mcpUI.execute("save", { title: "Saved" });
  assert.equal(calls[0].name, "save");
  assert.equal(calls[0].arguments.revision, 1);
  assert.equal(result.data.title, "Saved");
});
