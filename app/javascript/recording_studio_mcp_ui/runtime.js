(function (root) {
  "use strict";

  var config = {};
  var data = {};
  var dirty = false;
  var listeners = [];
  var fallbackExecutor = null;
  var hostReady = false;

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

  function allowedAction(aliasName) {
    return (config.actions || []).indexOf(aliasName) !== -1;
  }

  function executeThroughHost(aliasName, payload) {
    if (!root.McpAppsHost || !hostReady) return Promise.reject(new Error("MCP host is not connected"));
    return root.McpAppsHost.callTool(aliasName, payload);
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
    setFallbackExecutor: function (executor) {
      fallbackExecutor = executor;
    },
    execute: function (aliasName, payload) {
      if (!allowedAction(aliasName)) {
        return Promise.reject({ error: "unauthorized_action", message: "Action is not registered for this widget" });
      }
      var body = Object.assign({}, payload || {});
      if (data.revision) body.revision = data.revision;

      var runner = hostReady ? executeThroughHost(aliasName, body) : null;
      var request = runner || (fallbackExecutor ? fallbackExecutor(aliasName, body) : Promise.reject(new Error("No action transport")));

      return Promise.resolve(request).then(function (result) {
        var payloadResult = result && result.structuredContent ? result.structuredContent : result;
        if (payloadResult && payloadResult.ok === false) {
          return Promise.reject(payloadResult);
        }
        if (payloadResult && payloadResult.data) {
          mcpUI.applyData(payloadResult.data);
        }
        if (payloadResult && payloadResult.contextUpdate && root.McpAppsHost && hostReady) {
          root.McpAppsHost.updateModelContext(payloadResult.contextUpdate);
        }
        return payloadResult;
      });
    },
    start: function () {
      config = readConfig();
      setData(config.data || {});
      if (root.McpAppsHost && window.parent !== window) {
        return root.McpAppsHost.initialize({ name: config.widgetId, version: config.version }).then(function () {
          hostReady = true;
          root.McpAppsHost.onNotification("notifications/tools/list_changed", function () {});
          return config;
        }).catch(function () {
          hostReady = false;
          return config;
        });
      }
      return Promise.resolve(config);
    }
  };

  root.mcpUI = mcpUI;
})(window);
