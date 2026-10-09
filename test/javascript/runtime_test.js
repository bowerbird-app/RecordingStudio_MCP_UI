const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { attachMockHost } = require("./mcp_apps_host_mock");

const ENGINE_JS = path.join(__dirname, "../../app/javascript/recording_studio_mcp_ui");

function fakeDocument(config, extras) {
  extras = extras || {};
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
    querySelectorAll(selector) {
      if (selector === "[data-mcp-text]") return extras.textNodes || [];
      if (selector === "[data-controller~='mcp-editor']") return extras.editorRoots || [];
      return [];
    },
    addEventListener() {},
    createElement() { return { style: {}, textContent: "" }; },
    head: { appendChild() {} }
  };
}

function windowStub(config, extras) {
  extras = extras || {};
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
    document: fakeDocument(config, extras),
    postMessage() {}
  };
  windowLike.window = windowLike;
  windowLike.self = windowLike;
  windowLike.parent = windowLike;
  windowLike.addEventListener = function () {};
  windowLike.removeEventListener = function () {};
  return windowLike;
}

function loadEngine(windowLike, { sdk = true, boot = true } = {}) {
  const files = [];
  if (sdk) files.push("vendor/ext-apps.iife.js");
  files.push("runtime.js");
  if (boot) files.push("controllers/editor_controller.js", "boot.js");
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

test("ontoolresult applies structuredContent when registered before connect", async () => {
  const windowLike = windowStub({ widgetId: "projects.preview", data: {} });
  const order = [];
  let lastHandler;
  windowLike.parent = { postMessage() {} };
  windowLike.McpApps = {
    App: function App() {
      this.callServerTool = function () { return Promise.resolve({}); };
    },
    PostMessageTransport: function PostMessageTransport() {}
  };
  Object.defineProperty(windowLike.McpApps.App.prototype, "ontoolresult", {
    configurable: true,
    get() { return this._ontoolresult; },
    set(fn) {
      order.push("handler");
      lastHandler = fn;
      this._ontoolresult = fn;
    }
  });
  windowLike.McpApps.App.prototype.connect = function connect() {
    order.push("connect");
    return Promise.resolve();
  };

  const ctx = loadEngine(windowLike, { sdk: false, boot: false });
  const seen = [];
  ctx.mcpUI.onData(function (next) { seen.push(next); });
  await ctx.mcpUI.start();

  assert.deepEqual(order, [ "handler", "connect" ]);
  assert.equal(typeof lastHandler, "function");

  lastHandler({
    content: [],
    structuredContent: {
      id: "proj-1",
      title: "Widget House",
      description: "A coastal recording project.",
      status: "active",
      revision: 1
    }
  });
  assert.equal(ctx.mcpUI.data().title, "Widget House");
  assert.equal(ctx.mcpUI.data().description, "A coastal recording project.");
  assert.equal(ctx.mcpUI.data().status, "active");
  assert.equal(seen.some(function (row) { return row.title === "Widget House"; }), true);

  lastHandler({
    isError: true,
    structuredContent: { title: "Nope" }
  });
  assert.equal(ctx.mcpUI.data().title, "Widget House");
});

test("preview data-mcp-text binds after a tool-result that arrives before boot finishes", async () => {
  const title = { textContent: "", getAttribute(name) { return name === "data-mcp-text" ? "title" : null; } };
  const description = { textContent: "", getAttribute(name) { return name === "data-mcp-text" ? "description" : null; } };
  const status = { textContent: "", getAttribute(name) { return name === "data-mcp-text" ? "status" : null; } };
  const windowLike = windowStub(
    { widgetId: "projects.preview", data: {} },
    { textNodes: [ title, description, status ] }
  );
  windowLike.parent = { postMessage() {} };
  windowLike.McpApps = {
    App: function App() {
      this.callServerTool = function () { return Promise.resolve({}); };
    },
    PostMessageTransport: function PostMessageTransport() {}
  };
  Object.defineProperty(windowLike.McpApps.App.prototype, "ontoolresult", {
    configurable: true,
    get() { return this._ontoolresult; },
    set(fn) { this._ontoolresult = fn; }
  });
  windowLike.McpApps.App.prototype.connect = function connect() {
    this._ontoolresult({
      content: [],
      structuredContent: {
        title: "Widget House",
        description: "A coastal recording project.",
        status: "active"
      }
    });
    return Promise.resolve();
  };

  loadEngine(windowLike, { sdk: false, boot: true });
  await Promise.resolve();
  await Promise.resolve();

  assert.equal(title.textContent, "Widget House");
  assert.equal(description.textContent, "A coastal recording project.");
  assert.equal(status.textContent, "active");
});

function inputField(name, value) {
  const listeners = {};
  return {
    type: "text",
    value: value == null ? "" : String(value),
    getAttribute(attr) { return attr === "name" ? name : null; },
    addEventListener(type, fn) {
      (listeners[type] = listeners[type] || []).push(fn);
    },
    dispatch(type) {
      (listeners[type] || []).forEach((fn) => fn());
    },
    dataset: {}
  };
}

function actionButton(attr, value) {
  const listeners = {};
  const attrs = {};
  attrs[attr] = value;
  return {
    disabled: false,
    getAttribute(name) { return Object.prototype.hasOwnProperty.call(attrs, name) ? attrs[name] : null; },
    addEventListener(type, fn) {
      (listeners[type] = listeners[type] || []).push(fn);
    },
    dispatch(type) {
      (listeners[type] || []).forEach((fn) => fn());
    }
  };
}

function editorRoot(fields, extras) {
  extras = extras || {};
  return {
    classList: { toggle() {}, add() {} },
    querySelector() { return null; },
    querySelectorAll(selector) {
      if (selector === "[data-mcp-field]") return fields;
      if (selector === "[data-mcp-save]") return extras.saveButtons || [];
      if (selector === "[data-mcp-reset]") return extras.resetButtons || [];
      if (selector === "[data-mcp-error]") return extras.errorNodes || [];
      return [];
    }
  };
}

function attachFakeApp(windowLike, onConnect) {
  windowLike.parent = { postMessage() {} };
  windowLike.McpApps = {
    App: function App() {
      this.callServerTool = function () { return Promise.resolve({}); };
    },
    PostMessageTransport: function PostMessageTransport() {}
  };
  Object.defineProperty(windowLike.McpApps.App.prototype, "ontoolresult", {
    configurable: true,
    get() { return this._ontoolresult; },
    set(fn) { this._ontoolresult = fn; }
  });
  windowLike.McpApps.App.prototype.connect = function connect() {
    if (onConnect) onConnect(this._ontoolresult);
    return Promise.resolve();
  };
}

test("update-shaped tool result binds editor id revision and title", async () => {
  const idField = inputField("id", "");
  const revisionField = inputField("revision", "");
  const titleField = inputField("title", "");
  const windowLike = windowStub(
    { widgetId: "projects.editor", actions: { save: "projects.update" }, data: {} },
    { editorRoots: [ editorRoot([ idField, revisionField, titleField ]) ] }
  );
  attachFakeApp(windowLike, function (handler) {
    handler({
      content: [],
      structuredContent: {
        ok: true,
        data: {
          id: "proj-1",
          title: "Widget House",
          description: "A coastal recording project.",
          status: "draft",
          revision: 3
        },
        contextUpdate: "The user updated project proj-1."
      }
    });
  });

  const ctx = loadEngine(windowLike, { sdk: false, boot: true });
  await new Promise(function (resolve) { setTimeout(resolve, 0); });

  assert.equal(ctx.mcpUI.data().id, "proj-1");
  assert.equal(ctx.mcpUI.data().title, "Widget House");
  assert.equal(ctx.mcpUI.data().revision, 3);
  assert.equal(idField.value, "proj-1");
  assert.equal(revisionField.value, "3");
  assert.equal(titleField.value, "Widget House");
});

test("ChatGPT update tool result opens the editor with Mountain Lodge pre-filled", async () => {
  const chatgptCall = { id: "cabin-9", title: "Mountain Lodge" };
  const titleField = inputField("title", "");
  const descriptionField = inputField("description", "");
  const statusField = inputField("status", "");
  const idField = inputField("id", "");
  const revisionField = inputField("revision", "");
  const windowLike = windowStub(
    { widgetId: "projects.editor", actions: { save: "projects.update" }, data: {} },
    { editorRoots: [ editorRoot([ titleField, descriptionField, statusField, idField, revisionField ]) ] }
  );
  attachFakeApp(windowLike, function (handler) {
    handler({
      name: "projects.update",
      arguments: chatgptCall,
      content: [],
      structuredContent: {
        ok: true,
        data: {
          id: chatgptCall.id,
          title: chatgptCall.title,
          description: "A quiet room with a view.",
          status: "active",
          revision: 2
        },
        contextUpdate: "The user updated project cabin-9. The title is now \"Mountain Lodge\"."
      }
    });
  });

  const ctx = loadEngine(windowLike, { sdk: false, boot: true });
  await new Promise(function (resolve) { setTimeout(resolve, 0); });

  assert.deepEqual(chatgptCall, { id: "cabin-9", title: "Mountain Lodge" });
  assert.equal(ctx.mcpUI.data().title, "Mountain Lodge");
  assert.equal(ctx.mcpUI.data().description, "A quiet room with a view.");
  assert.equal(ctx.mcpUI.data().status, "active");
  assert.equal(ctx.mcpUI.data().id, "cabin-9");
  assert.equal(ctx.mcpUI.data().revision, 2);
  assert.equal(titleField.value, "Mountain Lodge");
  assert.equal(descriptionField.value, "A quiet room with a view.");
  assert.equal(statusField.value, "active");
  assert.equal(idField.value, "cabin-9");
  assert.equal(revisionField.value, "2");
});

test("editor save sends typed values after blur and reset restores opening data", async () => {
  const opening = {
    id: "proj-1",
    title: "warehouse",
    description: "A coastal recording project.",
    status: "active",
    revision: 1
  };
  const titleField = inputField("title", "");
  const descriptionField = inputField("description", "");
  const statusField = inputField("status", "");
  const idField = inputField("id", "");
  const revisionField = inputField("revision", "");
  const saveButton = actionButton("data-mcp-save", "save");
  const resetButton = actionButton("data-mcp-reset", "reset");
  const windowLike = windowStub(
    { widgetId: "projects.editor", actions: { save: "projects.update" }, data: opening },
    {
      editorRoots: [
        editorRoot(
          [ titleField, descriptionField, statusField, idField, revisionField ],
          { saveButtons: [ saveButton ], resetButtons: [ resetButton ] }
        )
      ]
    }
  );
  const calls = [];
  attachMockHost(windowLike, {
    onToolCall(params) {
      calls.push(params);
      return {
        ok: true,
        data: {
          id: "proj-1",
          title: "Mountain Lodge",
          description: "A quiet room with a view.",
          status: "active",
          revision: 2
        }
      };
    }
  });

  loadEngine(windowLike, { sdk: true, boot: true });
  await new Promise(function (resolve) { setTimeout(resolve, 0); });
  await new Promise(function (resolve) { setTimeout(resolve, 0); });

  assert.equal(titleField.value, "warehouse");
  assert.equal(descriptionField.value, "A coastal recording project.");

  titleField.value = "Mountain Lodge";
  titleField.dispatch("change");
  descriptionField.value = "A quiet room with a view.";
  descriptionField.dispatch("change");

  assert.equal(titleField.value, "Mountain Lodge");
  assert.equal(descriptionField.value, "A quiet room with a view.");

  saveButton.dispatch("click");
  await new Promise(function (resolve) { setTimeout(resolve, 0); });
  await new Promise(function (resolve) { setTimeout(resolve, 0); });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].name, "projects.update");
  assert.equal(calls[0].arguments.title, "Mountain Lodge");
  assert.equal(calls[0].arguments.description, "A quiet room with a view.");
  assert.equal(titleField.value, "Mountain Lodge");
  assert.equal(descriptionField.value, "A quiet room with a view.");
  assert.equal(revisionField.value, "2");

  resetButton.dispatch("click");
  assert.equal(titleField.value, "warehouse");
  assert.equal(descriptionField.value, "A coastal recording project.");
  assert.equal(revisionField.value, "1");
});

test("execute fills blank id and revision from widget data", async () => {
  const windowLike = windowStub({
    widgetId: "projects.editor",
    actions: { save: "projects.update" },
    data: {}
  });
  const calls = [];
  attachMockHost(windowLike, {
    onToolCall(params) {
      calls.push(params);
      return { ok: true, data: { id: "proj-1", title: "Test Update", revision: 5 } };
    }
  });
  const ctx = loadEngine(windowLike);
  await ctx.mcpUI.start();
  ctx.mcpUI.applyData({ id: "proj-1", revision: 4, title: "Old" });
  await ctx.mcpUI.execute("save", {
    title: "Test Update",
    description: "Lorem Ipsum",
    status: "draft",
    id: "",
    revision: ""
  });
  assert.equal(calls[0].arguments.id, "proj-1");
  assert.equal(calls[0].arguments.revision, 4);
  assert.equal(ctx.mcpUI.data().title, "Test Update");
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
