(function (root) {
  "use strict";

  var config = {};
  var data = {};
  var dirty = false;
  var listeners = [];
  var app = null;

  function readConfig() {
    var node = document.getElementById("mcp-ui-config");
    if (!node) return {};
    try {
      return JSON.parse(node.textContent || "{}");
    } catch (error) {
      return {};
    }
  }

  function notify() {
    listeners.slice().forEach(function (listener) {
      listener(data, { dirty: dirty });
    });
  }

  function setData(next) {
    data = next && typeof next === "object" ? next : {};
    notify();
  }

  function toolNameFor(aliasName) {
    var actions = config.actions;
    if (!actions || typeof actions !== "object" || Array.isArray(actions)) return undefined;
    if (!Object.prototype.hasOwnProperty.call(actions, aliasName)) return undefined;
    var name = actions[aliasName];
    if (typeof name !== "string" || !name) return undefined;
    return name;
  }

  function connectApp() {
    var Sdk = root.McpApps;
    if (!Sdk || !Sdk.App || !Sdk.PostMessageTransport) return Promise.resolve(null);
    if (window.parent === window) return Promise.resolve(null);

    var instance = new Sdk.App(
      { name: config.widgetId || "recording-studio-mcp-ui", version: config.version || "0.1.0" },
      {}
    );
    var transport = new Sdk.PostMessageTransport(window.parent, window.parent);
    return instance.connect(transport).then(function () {
      return instance;
    }).catch(function () {
      return null;
    });
  }

  function contextBlocks(update) {
    if (typeof update === "string") {
      return { content: [{ type: "text", text: update }] };
    }
    if (update && typeof update === "object") {
      if (update.content || update.structuredContent) return update;
      return { structuredContent: update };
    }
    return null;
  }

  function publishContext(update) {
    var params = contextBlocks(update);
    if (!params || !app || typeof app.updateModelContext !== "function") return;
    Promise.resolve(app.updateModelContext(params)).catch(function () {
      return null;
    });
  }

  var mcpUI = {
    config: function () { return config; },
    data: function () { return data; },
    isDirty: function () { return dirty; },
    onData: function (listener) {
      listeners.push(listener);
      return function () {
        listeners = listeners.filter(function (item) { return item !== listener; });
      };
    },
    applyData: function (next) {
      dirty = false;
      setData(next);
    },
    markDirty: function () {
      dirty = true;
      notify();
    },
    reset: function () {
      dirty = false;
      setData(config.data || {});
    },
    execute: function (aliasName, payload) {
      var toolName = toolNameFor(aliasName);
      if (!toolName) {
        return Promise.reject(new Error("Unknown action alias: " + aliasName));
      }
      if (!app || typeof app.callServerTool !== "function") {
        return Promise.reject(new Error("No action transport"));
      }

      var body = Object.assign({}, payload || {});
      if (data.revision) body.revision = data.revision;

      return app.callServerTool({ name: toolName, arguments: body }).then(function (result) {
        var payloadResult = result && result.structuredContent ? result.structuredContent : result;
        if (payloadResult && payloadResult.ok === false) {
          return Promise.reject(payloadResult);
        }
        if (payloadResult && payloadResult.data) {
          mcpUI.applyData(payloadResult.data);
        }
        if (payloadResult && payloadResult.contextUpdate) {
          publishContext(payloadResult.contextUpdate);
        }
        return payloadResult;
      });
    },
    start: function () {
      config = readConfig();
      setData(config.data || {});
      return connectApp().then(function (instance) {
        app = instance;
        return config;
      });
    }
  };

  root.mcpUI = mcpUI;
})(window);
