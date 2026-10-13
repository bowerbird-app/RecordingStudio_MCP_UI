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

function inputField(name, value, options) {
  options = options || {};
  const listeners = {};
  return {
    type: options.type || "text",
    value: value == null ? "" : String(value),
    checked: !!options.checked,
    disabled: !!options.disabled,
    getAttribute(attr) {
      if (attr === "name") return name;
      if (attr === "data-mcp-type") return options.mcpType || null;
      return null;
    },
    addEventListener(type, fn) {
      (listeners[type] = listeners[type] || []).push(fn);
    },
    dispatch(type) {
      (listeners[type] || []).forEach((fn) => fn());
    },
    dataset: options.dataset || {},
    closest: options.closest
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
    querySelector(selector) {
      if (selector === "[data-mcp-status]") return extras.statusNode || null;
      return null;
    },
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

function listParent(rows) {
  const parent = {
    childNodes: rows.slice(),
    insertBefore(node, ref) {
      const nodes = this.childNodes;
      const from = nodes.indexOf(node);
      if (from >= 0) nodes.splice(from, 1);
      const at = ref == null ? nodes.length : nodes.indexOf(ref);
      nodes.splice(at < 0 ? nodes.length : at, 0, node);
      node.parentNode = this;
    },
    ownerDocument: {
      createComment() {
        return { parentNode: null, nodeType: 8 };
      }
    }
  };
  rows.forEach((row) => { row.parentNode = parent; });
  return parent;
}

function sectionRow(title, body, selector) {
  const match = selector || "[data-mcp-row]";
  const row = {
    parentNode: null,
    closest(asked) { return asked === match ? this : null; }
  };
  row.fields = [
    inputField("sections[][title]", title, { closest: (selector) => row.closest(selector) }),
    inputField("sections[][body]", body, { closest: (selector) => row.closest(selector) })
  ];
  return row;
}

function sectionRoot(parent, extras) {
  extras = extras || {};
  const root = editorRoot([], extras);
  root.getAttribute = function (name) {
    if (name === "data-mcp-restore-order") return extras.restoreOrder ? "" : null;
    return null;
  };
  root.querySelectorAll = function (selector) {
    if (selector === "[data-mcp-field]") {
      return parent.childNodes.filter((node) => node.fields).flatMap((node) => node.fields);
    }
    if (selector === "[data-mcp-save]") return extras.saveButtons || [];
    if (selector === "[data-mcp-reset]") return extras.resetButtons || [];
    return [];
  };
  return root;
}

test("editor save collects repeated section fields in DOM order", async () => {
  const opening = {
    sections: [
      { title: "Intro", body: "Hello" },
      { title: "Close", body: "Goodbye" }
    ]
  };
  const first = sectionRow("", "");
  const second = sectionRow("", "");
  const parent = listParent([first, second]);
  const saveButton = actionButton("data-mcp-save", "save");
  const resetButton = actionButton("data-mcp-reset", "reset");
  const windowLike = windowStub(
    { widgetId: "pages.editor", actions: { save: "pages.update" }, data: opening },
    { editorRoots: [sectionRoot(parent, { saveButtons: [saveButton], resetButtons: [resetButton], restoreOrder: true })] }
  );
  const calls = [];
  attachMockHost(windowLike, {
    onToolCall(params) {
      calls.push(params);
      return { ok: true, data: opening };
    }
  });

  loadEngine(windowLike, { sdk: true, boot: true });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  assert.equal(first.fields[0].value, "Intro");
  assert.equal(second.fields[1].value, "Goodbye");

  parent.insertBefore(second, first);
  saveButton.dispatch("click");
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  assert.equal(JSON.stringify(calls[0].arguments.sections), JSON.stringify([
    { title: "Close", body: "Goodbye" },
    { title: "Intro", body: "Hello" }
  ]));

  resetButton.dispatch("click");
  assert.deepEqual(parent.childNodes.filter((node) => node.fields), [first, second]);
  assert.equal(first.fields[0].value, "Intro");
  assert.equal(second.fields[0].value, "Close");
});

test("editor save keeps string fields and reads json array checkbox and radio values", async () => {
  const published = inputField("published", "", { type: "checkbox", checked: true });
  const disabled = inputField("secret", "hidden", { disabled: true });
  const red = inputField("color", "red", { type: "radio", checked: false });
  const blue = inputField("color", "blue", { type: "radio", checked: true });
  const tags = inputField("tags", '["a","b"]', { mcpType: "array" });
  const meta = inputField("meta", '{"note":"hi"}', { mcpType: "json" });
  const broken = inputField("raw", "{", { mcpType: "json" });
  const heading = inputField("sections[10][heading]", "Stable");
  const saveButton = actionButton("data-mcp-save", "save");
  const windowLike = windowStub(
    {
      widgetId: "pages.editor",
      actions: { save: "pages.update" },
      data: { title: "Page", published: false, color: "red", tags: ["z"], meta: { note: "old" }, sections: {} }
    },
    {
      editorRoots: [
        editorRoot(
          [published, disabled, red, blue, tags, meta, broken, heading],
          { saveButtons: [saveButton] }
        )
      ]
    }
  );
  const calls = [];
  attachMockHost(windowLike, {
    onToolCall(params) {
      calls.push(params);
      return { ok: true, data: { title: "Page" } };
    }
  });

  loadEngine(windowLike, { sdk: true, boot: true });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  assert.equal(published.checked, false);
  assert.equal(red.checked, true);
  assert.equal(blue.checked, false);
  assert.equal(tags.value, '["z"]');

  published.checked = true;
  red.checked = false;
  blue.checked = true;
  tags.value = '["a","b"]';
  meta.value = '{"note":"hi"}';
  broken.value = "{";
  saveButton.dispatch("click");
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  assert.equal(calls[0].arguments.published, true);
  assert.equal(calls[0].arguments.secret, undefined);
  assert.equal(calls[0].arguments.color, "blue");
  assert.equal(JSON.stringify(calls[0].arguments.tags), JSON.stringify(["a", "b"]));
  assert.equal(JSON.stringify(calls[0].arguments.meta), JSON.stringify({ note: "hi" }));
  assert.equal(calls[0].arguments.raw, "{");
  assert.equal(JSON.stringify(calls[0].arguments.sections), JSON.stringify({ 10: { heading: "Stable" } }));
});

test("editor save ignores prototype keys", async () => {
  const proto = inputField("user[__proto__][polluted]", "yes");
  const viaConstructor = inputField("constructor[prototype][polluted]", "yes");
  const name = inputField("user[name]", "Ada");
  const saveButton = actionButton("data-mcp-save", "save");
  const windowLike = windowStub(
    { widgetId: "pages.editor", actions: { save: "pages.update" }, data: { user: { name: "" } } },
    { editorRoots: [editorRoot([proto, viaConstructor, name], { saveButtons: [saveButton] })] }
  );
  const calls = [];
  attachMockHost(windowLike, {
    onToolCall(params) {
      calls.push(params);
      return { ok: true, data: { user: { name: "Ada" } } };
    }
  });

  try {
    loadEngine(windowLike, { sdk: true, boot: true });
    await new Promise((resolve) => setTimeout(resolve, 0));
    await new Promise((resolve) => setTimeout(resolve, 0));

    name.value = "Ada";
    saveButton.dispatch("click");
    await new Promise((resolve) => setTimeout(resolve, 0));
    await new Promise((resolve) => setTimeout(resolve, 0));

    assert.equal({}.polluted, undefined);
    assert.equal(Object.prototype.polluted, undefined);
    assert.equal(calls[0].arguments.user.name, "Ada");
    assert.equal(calls[0].arguments.user.polluted, undefined);
  } finally {
    delete Object.prototype.polluted;
  }
});

test("editor reset restores only rows that opt in", async () => {
  const opening = {
    sections: [
      { title: "Intro", body: "Hello" },
      { title: "Close", body: "Goodbye" }
    ]
  };
  const plain = sectionRow("", "", "tr");
  const marked = sectionRow("", "", "li");
  const parent = listParent([plain, marked]);
  const resetButton = actionButton("data-mcp-reset", "reset");
  const windowLike = windowStub(
    { widgetId: "pages.editor", actions: { save: "pages.update" }, data: opening },
    { editorRoots: [sectionRoot(parent, { resetButtons: [resetButton], restoreOrder: true })] }
  );
  attachMockHost(windowLike, { onToolCall() { return { ok: true, data: opening }; } });

  loadEngine(windowLike, { sdk: true, boot: true });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  parent.insertBefore(marked, plain);
  resetButton.dispatch("click");
  assert.deepEqual(parent.childNodes.filter((node) => node.fields), [marked, plain]);
});

test("editor reset leaves opted-in rows in place without data-mcp-restore-order", async () => {
  const opening = {
    sections: [
      { title: "Intro", body: "Hello" },
      { title: "Close", body: "Goodbye" }
    ]
  };
  const first = sectionRow("", "");
  const second = sectionRow("", "");
  const parent = listParent([first, second]);
  const resetButton = actionButton("data-mcp-reset", "reset");
  const windowLike = windowStub(
    { widgetId: "pages.editor", actions: { save: "pages.update" }, data: opening },
    { editorRoots: [sectionRoot(parent, { resetButtons: [resetButton] })] }
  );
  attachMockHost(windowLike, { onToolCall() { return { ok: true, data: opening }; } });

  loadEngine(windowLike, { sdk: true, boot: true });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  parent.insertBefore(second, first);
  resetButton.dispatch("click");
  assert.deepEqual(parent.childNodes.filter((node) => node.fields), [second, first]);
});

test("editor save status uses packaged i18n with english fallbacks", async () => {
  const statusNode = { textContent: "", hidden: true, dataset: {} };
  const saveButton = actionButton("data-mcp-save", "save");
  const windowLike = windowStub(
    {
      widgetId: "projects.editor",
      actions: { save: "projects.update" },
      data: { title: "Beach House" },
      i18n: {
        editor: { saving: "HOST Saving…", saved: "HOST Saved", save_failed: "HOST Save failed" }
      }
    },
    {
      editorRoots: [
        editorRoot([], { saveButtons: [saveButton], statusNode })
      ]
    }
  );
  const ctx = loadEngine(windowLike, { sdk: false, boot: true });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await ctx.mcpUI.start();
  ctx.mcpUI.execute = function () { return Promise.reject({}); };

  saveButton.dispatch("click");
  assert.equal(statusNode.textContent, "HOST Saving…");
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  assert.equal(statusNode.dataset.kind, "error");
  assert.equal(statusNode.textContent, "HOST Save failed");
});

test("editor save status falls back to english when i18n blob is absent", async () => {
  const statusNode = { textContent: "", hidden: true, dataset: {} };
  const saveButton = actionButton("data-mcp-save", "save");
  const windowLike = windowStub(
    {
      widgetId: "projects.editor",
      actions: { save: "projects.update" },
      data: { title: "Beach House" }
    },
    {
      editorRoots: [
        editorRoot([], { saveButtons: [saveButton], statusNode })
      ]
    }
  );
  const ctx = loadEngine(windowLike, { sdk: false, boot: true });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await ctx.mcpUI.start();
  ctx.mcpUI.execute = function () { return Promise.reject({}); };

  saveButton.dispatch("click");
  assert.equal(statusNode.textContent, "Saving…");
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  assert.equal(statusNode.textContent, "Save failed");
});