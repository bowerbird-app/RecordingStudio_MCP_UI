(function (root) {
  "use strict";

  var nextId = 1;
  var pending = {};

  function isMessage(event) {
    return event && event.data && event.data.jsonrpc === "2.0";
  }

  function onMessage(event) {
    if (!isMessage(event)) return;
    var message = event.data;
    if (Object.prototype.hasOwnProperty.call(message, "id") && pending[message.id]) {
      var entry = pending[message.id];
      delete pending[message.id];
      if (message.error) {
        entry.reject(message.error);
      } else {
        entry.resolve(message.result);
      }
    }
  }

  window.addEventListener("message", onMessage);

  function sendRequest(method, params) {
    var id = nextId++;
    return new Promise(function (resolve, reject) {
      pending[id] = { resolve: resolve, reject: reject };
      window.parent.postMessage({ jsonrpc: "2.0", id: id, method: method, params: params || {} }, "*");
    });
  }

  function sendNotification(method, params) {
    window.parent.postMessage({ jsonrpc: "2.0", method: method, params: params || {} }, "*");
  }

  function onNotification(method, handler) {
    window.addEventListener("message", function (event) {
      if (!isMessage(event)) return;
      if (event.data.method === method) handler(event.data.params || {});
    });
  }

  root.McpAppsHost = {
    sendRequest: sendRequest,
    sendNotification: sendNotification,
    onNotification: onNotification,
    initialize: function (appInfo) {
      return sendRequest("ui/initialize", {
        protocolVersion: "2025-06-18",
        appCapabilities: { tools: {} },
        appInfo: appInfo || { name: "recording-studio-mcp-ui", version: "0.1.0" }
      }).then(function (result) {
        sendNotification("ui/notifications/initialized", {});
        return result;
      });
    },
    callTool: function (name, args) {
      return sendRequest("tools/call", { name: name, arguments: args || {} });
    },
    updateModelContext: function (text) {
      return sendRequest("sampling/createMessage", {
        messages: [{ role: "user", content: { type: "text", text: text } }],
        maxTokens: 1
      }).catch(function () {
        sendNotification("notifications/message", { level: "info", data: text });
        return null;
      });
    }
  };
})(window);
