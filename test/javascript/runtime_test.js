const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { attachMockHost } = require("./mcp_apps_host_mock");

const ENGINE_JS = path.join(__dirname, "../../app/javascript/recording_studio_mcp_ui");

function fakeDocument(config) {
  const element = {
    style: {},
    getAttribute() { return null; },
    setAttribute() {},
    classList: { contains() { return false; } },
    getBoundingClientRect() { return { height: 100, width: 400 }; }
  };
  return {
    readyState: "complete",
    documentElement: element,
    body: element,
    getElementById(id) {
      if (id === "mcp-ui-config") return { textContent: JSON.stringify(config) };
      return null;
    },
    querySelector() { return null; },
    querySelectorAll() { return []; },
    addEventListener() {},
    createElement() { return { style: {}, textContent: "" }; },
    head: { appendChild() {} }
  };
}

function windowStub(config) {
  const windowLike = {
    innerWidth: 400,
    location: { origin: "https://example.test", pathname: "/", search: "" },
    URL,
    setTimeout,
    clearTimeout,
    queueMicrotask,
    Promise,
    console,
    ResizeObserver: class {
      observe() {}
      disconnect() {}
    },
    requestAnimationFrame(fn) { fn(); },
    document: fakeDocument(config),
    postMessage() {}
  };
  windowLike.window = windowLike;
  windowLike.self = windowLike;
  windowLike.parent = windowLike;
  windowLike.addEventListener = function () {};
  windowLike.removeEventListener = function () {};
  return windowLike;
}

function loadEngine(windowLike, { sdk = true } = {}) {
  const files = [];
  if (sdk) files.push("vendor/ext-apps.iife.js");
  files.push("runtime.js", "controllers/editor_controller.js", "boot.js");
  const context = vm.createContext(windowLike);
  files.forEach((file) => {
    vm.runInContext(
      fs.readFileSync(path.join(ENGINE_JS, file), "utf8"),
      context,
      { filename: file }
    );
  });
  return context;
}

test("execute rejects unregistered action aliases without calling the host", async () => {
  const windowLike = windowStub({
    widgetId: "projects.editor",
    actions: { save: "projects.update" },
    data: { title: "Beach House" }
  });
  const calls = [];
  attachMockHost(windowLike, {
    onToolCall(params) {
      calls.push(params);
      return { ok: true, data: {} };
    }
  });
  const ctx = loadEngine(windowLike);
  await ctx.mcpUI.start();
  await assert.rejects(() => ctx.mcpUI.execute("destroy", {}), (error) => {
    assert.equal(error.message, "Unknown action alias: destroy");
    return true;
  });
  assert.equal(calls.length, 0);
});

test("execute rejects when no host is connected", async () => {
  const windowLike = windowStub({
    widgetId: "projects.editor",
    actions: { save: "projects.update" },
    data: { title: "Old" }
  });
  const ctx = loadEngine(windowLike, { sdk: false });
  await ctx.mcpUI.start();
  await assert.rejects(() => ctx.mcpUI.execute("save", {}), (error) => {
    assert.equal(error.message, "No action transport");
    return true;
  });
});

test("dirty tracking resets", async () => {
  const windowLike = windowStub({ actions: { save: "projects.update" }, data: { title: "A" } });
  const ctx = loadEngine(windowLike, { sdk: false });
  await ctx.mcpUI.start();
  ctx.mcpUI.markDirty();
  assert.equal(ctx.mcpUI.isDirty(), true);
  ctx.mcpUI.reset();
  assert.equal(ctx.mcpUI.isDirty(), false);
  assert.equal(ctx.mcpUI.data().title, "A");
});

test("execute rejects MCP isError results", async () => {
  const windowLike = windowStub({
    widgetId: "projects.editor",
    actions: { save: "projects.update" },
    data: { title: "Beach House" }
  });
  const ctx = loadEngine(windowLike);
  attachMockHost(windowLike, {
    onToolCall() {
      return {
        isError: true,
        content: [{ type: "text", text: "Title can't be blank" }],
        structuredContent: { error: "validation_failed", errors: { title: "can't be blank" } }
      };
    }
  });
  await ctx.mcpUI.start();
  await assert.rejects(() => ctx.mcpUI.execute("save", { title: "" }), (error) => {
    assert.equal(error.error, "validation_failed");
    assert.equal(error.errors.title, "can't be blank");
    return true;
  });
});

test("execute rejects isError text when structuredContent is missing", async () => {
  const windowLike = windowStub({
    widgetId: "projects.editor",
    actions: { save: "projects.update" },
    data: { title: "Beach House" }
  });
  attachMockHost(windowLike, {
    onToolCall() {
      return {
        isError: true,
        content: [{ type: "text", text: "unauthorized" }]
      };
    }
  });
  const ctx = loadEngine(windowLike);
  await ctx.mcpUI.start();
  await assert.rejects(() => ctx.mcpUI.execute("save", {}), (error) => {
    assert.equal(error.message, "unauthorized");
    return true;
  });
});

test("execute maps the alias to the real tool name in callServerTool", async () => {
  const windowLike = windowStub({
    widgetId: "projects.editor",
    version: "1.0.0",
    actions: { save: "projects.update" },
    data: { title: "Old", revision: 1 }
  });
  const calls = [];
  attachMockHost(windowLike, {
    onToolCall(params) {
      calls.push(params);
      return { ok: true, data: { title: "Saved", revision: 2 } };
    }
  });

  const ctx = loadEngine(windowLike);
  await ctx.mcpUI.start();
  const result = await ctx.mcpUI.execute("save", { title: "Saved" });
  assert.equal(calls[0].name, "projects.update");
  assert.equal(calls[0].arguments.revision, 1);
  assert.equal(result.data.title, "Saved");
  assert.equal(ctx.mcpUI.data().title, "Saved");
});
