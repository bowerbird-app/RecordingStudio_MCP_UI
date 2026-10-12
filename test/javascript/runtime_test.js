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

class ListNode {
  constructor() {
    this.childNodes = [];
    this.parentNode = null;
    this._text = "";
  }

  appendChild(child) {
    if (child.parentNode) child.remove();
    child.parentNode = this;
    this.childNodes.push(child);
    return child;
  }

  insertBefore(node, ref) {
    if (node.parentNode) node.remove();
    node.parentNode = this;
    const index = ref ? this.childNodes.indexOf(ref) : -1;
    if (index < 0) this.childNodes.push(node);
    else this.childNodes.splice(index, 0, node);
    return node;
  }

  remove() {
    if (!this.parentNode) return;
    const index = this.parentNode.childNodes.indexOf(this);
    if (index >= 0) this.parentNode.childNodes.splice(index, 1);
    this.parentNode = null;
  }

  get textContent() {
    if (this.childNodes.length === 0) return this._text;
    return this.childNodes.map((node) => node.textContent).join("");
  }

  set textContent(value) {
    this._text = String(value);
    this.childNodes = [];
  }
}

class ListFragment extends ListNode {
  constructor(children) {
    super();
    this.nodeType = 11;
    (children || []).forEach((child) => this.appendChild(child));
  }

  cloneNode(deep) {
    const copy = new ListFragment();
    if (deep) this.childNodes.forEach((child) => copy.appendChild(child.cloneNode(true)));
    return copy;
  }
}

class ListElement extends ListNode {
  constructor(tag, attrs) {
    super();
    this.nodeType = 1;
    this.tagName = String(tag).toUpperCase();
    this.attrs = Object.assign({}, attrs);
    this.classList = { toggle() {}, add() {}, remove() {}, contains() { return false; } };
    this._listeners = {};
  }

  get value() {
    return Object.prototype.hasOwnProperty.call(this, "_value") ? this._value : (this.getAttribute("value") || "");
  }

  set value(next) {
    this._value = next == null ? "" : String(next);
  }

  addEventListener(type, fn) {
    (this._listeners[type] = this._listeners[type] || []).push(fn);
  }

  dispatchEvent(event) {
    (this._listeners[event.type] || []).forEach((fn) => fn(event));
  }

  getAttribute(name) {
    return Object.prototype.hasOwnProperty.call(this.attrs, name) ? this.attrs[name] : null;
  }

  setAttribute(name, value) {
    this.attrs[name] = String(value);
  }

  hasAttribute(name) {
    return Object.prototype.hasOwnProperty.call(this.attrs, name);
  }

  removeAttribute(name) {
    delete this.attrs[name];
  }

  set innerHTML(_value) {
    throw new Error("innerHTML is not allowed");
  }

  matches(selector) {
    if (selector.indexOf("template[") === 0 && selector.endsWith("]")) {
      return this.tagName === "TEMPLATE" && this.hasAttribute(selector.slice("template[".length, -1));
    }
    const token = /^\[([^\]~]+)~=["']([^"']+)["']\]$/.exec(selector);
    if (token) {
      return (this.getAttribute(token[1]) || "").split(/\s+/).indexOf(token[2]) !== -1;
    }
    if (selector.indexOf("[") === 0 && selector.endsWith("]") && selector.indexOf("~=") === -1 && selector.indexOf("=") === -1) {
      return this.hasAttribute(selector.slice(1, -1));
    }
    return false;
  }

  closest(selector) {
    let node = this;
    while (node) {
      if (node.nodeType === 1 && node.matches(selector)) return node;
      node = node.parentNode;
    }
    return null;
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0] || null;
  }

  querySelectorAll(selector) {
    const found = [];
    collectElements(this, selector, found);
    return found;
  }

  cloneNode(deep) {
    const copy = new ListElement(this.tagName.toLowerCase(), this.attrs);
    copy._text = this._text;
    if (deep) this.childNodes.forEach((child) => copy.appendChild(child.cloneNode(true)));
    if (this.content) copy.content = this.content.cloneNode(true);
    return copy;
  }
}

function collectElements(root, selector, found) {
  root.childNodes.forEach((node) => {
    if (node.nodeType !== 1) return;
    if (node.matches(selector)) found.push(node);
    if (node.tagName === "TEMPLATE") return;
    collectElements(node, selector, found);
  });
}

function listElement(tag, attrs, children) {
  const node = new ListElement(tag, attrs);
  (children || []).forEach((child) => node.appendChild(child));
  return node;
}

function listDocument(config, body) {
  const configNode = listElement("script", { id: "mcp-ui-config" });
  configNode.textContent = JSON.stringify(config);
  return {
    readyState: "complete",
    documentElement: body,
    body,
    head: { appendChild() {} },
    getElementById(id) {
      if (id === "mcp-ui-config") return configNode;
      return null;
    },
    querySelector(selector) {
      return this.querySelectorAll(selector)[0] || null;
    },
    querySelectorAll(selector) {
      const found = [];
      collectElements(body, selector, found);
      return found;
    },
    addEventListener() {},
    createElement(tag) {
      return listElement(tag);
    }
  };
}

function topicsList() {
  const label = listElement("span", { "data-mcp-text": "" });
  const chip = listElement("span", { class: "chip" }, [ label ]);
  const template = listElement("template", { "data-mcp-list-item": "" });
  template.content = new ListFragment([ chip ]);
  const group = listElement("div", {}, [ template ]);
  const empty = listElement("p", { "data-mcp-list-empty": "" });
  empty.textContent = "No topics yet.";
  const list = listElement("div", { "data-mcp-list": "topics" }, [ group, empty ]);
  return { list, empty, body: listElement("div", {}, [ list ]) };
}

test("tool-result with 3 topics renders 3 chips and an empty list clears them", async () => {
  const topics = topicsList();
  const windowLike = windowStub({ widgetId: "pages.topics", data: {} });
  windowLike.document = listDocument({ widgetId: "pages.topics", data: {} }, topics.body);
  let handler;
  attachFakeApp(windowLike, function (next) {
    handler = next;
    next({
      content: [],
      structuredContent: { topics: [ "Launch", "Story", "Press <kit>" ] }
    });
  });

  const ctx = loadEngine(windowLike, { sdk: false, boot: true });
  await new Promise(function (resolve) { setTimeout(resolve, 0); });

  let chips = topics.list.querySelectorAll("[data-mcp-list-entry]");
  assert.equal(chips.length, 3);
  assert.deepEqual(chips.map((chip) => chip.textContent), [ "Launch", "Story", "Press <kit>" ]);
  assert.equal(elementWithTag(topics.list, "IMG"), null);
  assert.equal(topics.empty.hasAttribute("hidden"), true);
  assert.equal(topics.empty.textContent, "No topics yet.");

  ctx.mcpUI.markDirty();
  assert.equal(topics.list.querySelectorAll("[data-mcp-list-entry]").length, 3);

  handler({
    isError: true,
    structuredContent: { topics: [] }
  });
  assert.equal(topics.list.querySelectorAll("[data-mcp-list-entry]").length, 3);

  handler({ content: [], structuredContent: { topics: [] } });
  chips = topics.list.querySelectorAll("[data-mcp-list-entry]");
  assert.equal(chips.length, 0);
  assert.equal(topics.empty.hasAttribute("hidden"), false);

  handler({ content: [], structuredContent: { topics: "Launch" } });
  assert.equal(topics.list.querySelectorAll("[data-mcp-list-entry]").length, 0);
  assert.equal(topics.empty.hasAttribute("hidden"), false);
});

test("list binder fills object fields and leaves them alone when the form is dirty", async () => {
  const heading = listElement("p", { "data-mcp-text": "heading" });
  const body = listElement("p", { "data-mcp-text": "body" });
  const item = listElement("div", {}, [ heading, body ]);
  const template = listElement("template", { "data-mcp-list-item": "" });
  template.content = new ListFragment([ item ]);
  const empty = listElement("p", { "data-mcp-list-empty": "" });
  const list = listElement("div", { "data-mcp-list": "sections" }, [ template, empty ]);
  const title = listElement("h3", { "data-mcp-text": "title" });
  const root = listElement("div", {}, [ title, list ]);
  const windowLike = windowStub({ widgetId: "pages.tabs", data: {} });
  windowLike.document = listDocument({ widgetId: "pages.tabs", data: {} }, root);
  attachFakeApp(windowLike, function (next) {
    next({
      content: [],
      structuredContent: {
        title: "Launch notes",
        heading: "WRONG",
        sections: [ { heading: "Open", body: "Say hello." } ]
      }
    });
  });

  const ctx = loadEngine(windowLike, { sdk: false, boot: true });
  await new Promise(function (resolve) { setTimeout(resolve, 0); });

  function slotText(entry, field) {
    const slot = entry.querySelectorAll("[data-mcp-text]").find((node) => node.getAttribute("data-mcp-text") === field);
    return slot ? slot.textContent : null;
  }

  const entries = list.querySelectorAll("[data-mcp-list-entry]");
  assert.equal(entries.length, 1);
  assert.equal(slotText(entries[0], "heading"), "Open");
  assert.equal(slotText(entries[0], "body"), "Say hello.");
  assert.equal(title.textContent, "Launch notes");

  ctx.mcpUI.markDirty();
  const live = list.querySelectorAll("[data-mcp-list-entry]");
  assert.equal(live.length, 1);
  assert.equal(slotText(live[0], "heading"), "Open");
});

test("list binder fills fields and attributes on each clone and keeps input names", async () => {
  const row = listElement("tr", {
    "data-mcp-row": "",
    "data-mcp-attr-data-id": "id"
  });
  const id = listElement("input", { type: "hidden", name: "links[][id]", "data-mcp-field": "true", value: "" });
  const label = listElement("input", { type: "text", name: "links[][label]", "data-mcp-field": "true", value: "" });
  const url = listElement("input", { type: "text", name: "links[][url]", "data-mcp-field": "true", value: "" });
  const destroy = listElement("input", { type: "hidden", name: "links[][_destroy]", "data-mcp-field": "true", value: "0" });
  const picked = listElement("input", { type: "checkbox", name: "links[][picked]", "data-mcp-field": "true" });
  const trigger = listElement("button", {
    type: "button",
    "data-mcp-attr-id": "note-$index-trigger",
    "data-mcp-attr-aria-controls": "note-$index-content"
  });
  const panel = listElement("div", {
    "data-mcp-attr-id": "note-$index-content",
    "data-mcp-attr-aria-labelledby": "id"
  });
  const visible = listElement("span", { "data-mcp-text": "label" });
  row.appendChild(id);
  row.appendChild(label);
  row.appendChild(url);
  row.appendChild(destroy);
  row.appendChild(picked);
  row.appendChild(trigger);
  row.appendChild(panel);
  row.appendChild(visible);
  const template = listElement("template", { "data-mcp-list-item": "" });
  template.content = new ListFragment([ row ]);
  const empty = listElement("p", { "data-mcp-list-empty": "" });
  const list = listElement("div", { "data-mcp-list": "links" }, [ template, empty ]);
  const added = listElement("tr", { "data-mcp-row": "" });
  const windowLike = windowStub({ widgetId: "pages.links", data: {} });
  windowLike.document = listDocument({ widgetId: "pages.links", data: {} }, listElement("div", {}, [ list ]));
  let handler;
  attachFakeApp(windowLike, function (next) { handler = next; });

  loadEngine(windowLike, { sdk: false, boot: true });
  await new Promise((resolve) => setTimeout(resolve, 0));

  handler({
    content: [],
    structuredContent: {
      links: [
        { id: "notes", label: "Notes", url: "https://example.com/notes", picked: true },
        { id: "press", label: "Press <kit>", url: "https://example.com/press", picked: false }
      ]
    }
  });

  const entries = list.querySelectorAll("[data-mcp-list-entry]");
  assert.equal(entries.length, 2);
  assert.equal(entries[0].getAttribute("data-mcp-row"), "");
  assert.equal(entries[0].getAttribute("data-id"), "notes");
  assert.equal(entries[1].getAttribute("data-id"), "press");
  const firstLabel = entries[0].querySelectorAll("[data-mcp-field]").find((node) => node.getAttribute("name") === "links[][label]");
  const secondLabel = entries[1].querySelectorAll("[data-mcp-field]").find((node) => node.getAttribute("name") === "links[][label]");
  assert.equal(firstLabel.value, "Notes");
  assert.equal(firstLabel.getAttribute("name"), "links[][label]");
  assert.equal(secondLabel.value, "Press <kit>");
  assert.equal(elementWithTag(list, "IMG"), null);
  assert.equal(entries[0].querySelectorAll("[data-mcp-text]")[0].textContent, "Notes");
  const firstUrl = entries[0].querySelectorAll("[data-mcp-field]").find((node) => node.getAttribute("name") === "links[][url]");
  const firstDestroy = entries[0].querySelectorAll("[data-mcp-field]").find((node) => node.getAttribute("name") === "links[][_destroy]");
  const firstPicked = entries[0].querySelectorAll("[data-mcp-field]").find((node) => node.getAttribute("name") === "links[][picked]");
  assert.equal(firstUrl.value, "https://example.com/notes");
  assert.equal(firstDestroy.value, "0");
  assert.equal(firstPicked.checked, true);
  assert.equal(elementWithTag(entries[0], "BUTTON").getAttribute("id"), "note-0-trigger");
  assert.equal(elementWithTag(entries[0], "BUTTON").getAttribute("aria-controls"), "note-0-content");
  assert.equal(elementWithTag(entries[1], "BUTTON").getAttribute("id"), "note-1-trigger");
  assert.equal(elementWithTag(entries[1], "DIV").getAttribute("id"), "note-1-content");
  assert.equal(elementWithTag(entries[0], "DIV").getAttribute("aria-labelledby"), "notes");

  list.appendChild(added);
  handler({ content: [], structuredContent: { links: [] } });
  assert.equal(list.querySelectorAll("[data-mcp-list-entry]").length, 0);
  assert.equal(list.querySelectorAll("[data-mcp-row]").length, 0);
  assert.equal(empty.hasAttribute("hidden"), false);
});

test("cloned rows save in DOM order and reset restores the opening tool result", async () => {
  const id = listElement("input", { type: "hidden", name: "links[][id]", "data-mcp-field": "true" });
  const label = listElement("input", { type: "text", name: "links[][label]", "data-mcp-field": "true" });
  const row = listElement("tr", { "data-mcp-row": "" }, [ id, label ]);
  const template = listElement("template", { "data-mcp-list-item": "" });
  template.content = new ListFragment([ row ]);
  const list = listElement("tbody", { "data-mcp-list": "links" }, [ template ]);
  const title = listElement("input", { name: "title", "data-mcp-field": "true" });
  const save = listElement("button", { type: "button", "data-mcp-save": "save" });
  const reset = listElement("button", { type: "button", "data-mcp-reset": "reset" });
  const editor = listElement("div", { "data-controller": "mcp-editor", "data-mcp-restore-order": "" }, [ title, list, save, reset ]);
  const windowLike = windowStub({ widgetId: "pages.links", actions: { save: "pages.update" }, data: {} });
  windowLike.document = listDocument(
    { widgetId: "pages.links", actions: { save: "pages.update" }, data: {} },
    listElement("div", {}, [ editor ])
  );
  const calls = [];
  let toolResult;
  windowLike.parent = { postMessage() {} };
  windowLike.McpApps = {
    App: function App() {
      this.callServerTool = function (params) {
        calls.push(params);
        return Promise.resolve({
          content: [],
          structuredContent: {
            ok: true,
            data: {
              title: "Launch notes",
              links: [
                { id: "press", label: "Press desk" },
                { id: "notes", label: "Notes" }
              ]
            }
          }
        });
      };
    },
    PostMessageTransport: function PostMessageTransport() {}
  };
  Object.defineProperty(windowLike.McpApps.App.prototype, "ontoolresult", {
    configurable: true,
    get() { return this._ontoolresult; },
    set(fn) { this._ontoolresult = fn; toolResult = fn; }
  });
  windowLike.McpApps.App.prototype.connect = function connect() {
    return Promise.resolve();
  };

  loadEngine(windowLike, { sdk: false, boot: true });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  toolResult({
    content: [],
    structuredContent: {
      title: "Launch notes",
      links: [
        { id: "notes", label: "Notes" },
        { id: "press", label: "Press" }
      ]
    }
  });

  let rows = list.querySelectorAll("[data-mcp-row]");
  assert.equal(rows.length, 2);
  assert.equal(title.value, "Launch notes");
  const first = rows[0];
  const second = rows[1];
  const labelOf = (entry) => entry.querySelectorAll("[data-mcp-field]").find((node) => node.getAttribute("name") === "links[][label]");
  labelOf(second).value = "Press desk";
  list.insertBefore(second, first);
  save.dispatchEvent({ type: "click" });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  assert.equal(JSON.stringify(calls[0].arguments.links), JSON.stringify([
    { id: "press", label: "Press desk" },
    { id: "notes", label: "Notes" }
  ]));

  rows = list.querySelectorAll("[data-mcp-row]");
  assert.equal(labelOf(rows[0]).value, "Press desk");
  reset.dispatchEvent({ type: "click" });
  rows = list.querySelectorAll("[data-mcp-row]");
  assert.equal(rows.length, 2);
  assert.equal(labelOf(rows[0]).value, "Notes");
  assert.equal(labelOf(rows[1]).value, "Press");
  assert.equal(title.value, "Launch notes");
});

test("list binder reconnects a row controller after clones land and does not bind twice", async () => {
  const row = listElement("tr", {
    "data-mcp-row": "",
    "data-mcp-attr-data-id": "id",
    "data-flat-pack--table-sortable-target": "row"
  });
  const label = listElement("input", { type: "text", name: "links[][label]", "data-mcp-field": "true" });
  row.appendChild(label);
  const template = listElement("template", { "data-mcp-list-item": "" });
  template.content = new ListFragment([ row ]);
  const list = listElement("tbody", { "data-mcp-list": "links" }, [ template ]);
  const shell = listElement("div", {
    "data-controller": "flat-pack--table-sortable",
    "data-mcp-reconnect": "flat-pack--table-sortable"
  }, [ list ]);
  const windowLike = windowStub({ widgetId: "pages.links", data: {} });
  windowLike.document = listDocument({ widgetId: "pages.links", data: {} }, listElement("div", {}, [ shell ]));
  const binds = [];
  const controller = {
    get rowTargets() {
      const found = [];
      function walk(node) {
        if (!node || node.nodeType !== 1 || node.tagName === "TEMPLATE") return;
        if (node.getAttribute("data-flat-pack--table-sortable-target") === "row") found.push(node);
        (node.childNodes || []).forEach(walk);
      }
      walk(shell);
      return found;
    },
    connect() {
      this.rowTargets.forEach((entry) => {
        entry._binds = (entry._binds || 0) + 1;
        entry.setAttribute("draggable", "true");
        binds.push(entry.getAttribute("data-id") || entry._binds);
      });
    }
  };
  windowLike.Stimulus = {
    getControllerForElementAndIdentifier(element, identifier) {
      if (element === shell && identifier === "flat-pack--table-sortable") return controller;
      return null;
    }
  };
  let handler;
  attachFakeApp(windowLike, function (next) { handler = next; });

  loadEngine(windowLike, { sdk: false, boot: true });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));
  assert.equal(binds.length, 0);

  handler({
    content: [],
    structuredContent: {
      links: [
        { id: "notes", label: "Notes" },
        { id: "press", label: "Press" },
        { id: "site", label: "Site" }
      ]
    }
  });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));

  let entries = list.querySelectorAll("[data-mcp-list-entry]");
  assert.equal(entries.length, 3);
  assert.deepEqual(entries.map((entry) => entry.getAttribute("draggable")), [ "true", "true", "true" ]);
  assert.deepEqual(entries.map((entry) => entry._binds), [ 1, 1, 1 ]);

  await new Promise((resolve) => setTimeout(resolve, 0));
  assert.deepEqual(entries.map((entry) => entry._binds), [ 1, 1, 1 ]);

  handler({
    content: [],
    structuredContent: {
      links: [
        { id: "site", label: "Site" },
        { id: "notes", label: "Notes" }
      ]
    }
  });
  await new Promise((resolve) => setTimeout(resolve, 0));
  await new Promise((resolve) => setTimeout(resolve, 0));
  entries = list.querySelectorAll("[data-mcp-list-entry]");
  assert.equal(entries.length, 2);
  assert.deepEqual(entries.map((entry) => entry.getAttribute("data-id")), [ "site", "notes" ]);
  assert.deepEqual(entries.map((entry) => entry._binds), [ 1, 1 ]);
});

function elementWithTag(root, tag) {
  if (root.tagName === tag) return root;
  const children = root.childNodes || [];
  for (const child of children) {
    if (child.nodeType !== 1) continue;
    const found = elementWithTag(child, tag);
    if (found) return found;
  }
  return null;
}
