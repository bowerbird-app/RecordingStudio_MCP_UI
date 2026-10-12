(function () {
  "use strict";

  var frame = document.getElementById("mcp-ui-frame");
  if (!frame) return;

  var ready = false;
  var queued = null;

  function toolResult(topics) {
    return {
      jsonrpc: "2.0",
      method: "ui/notifications/tool-result",
      params: {
        content: [{ type: "text", text: topics.join(", ") }],
        structuredContent: { topics: topics }
      }
    };
  }

  function deliver(topics) {
    if (!frame.contentWindow) return;
    frame.contentWindow.postMessage(toolResult(topics), "*");
  }

  function publish(topics) {
    if (!ready) {
      queued = topics;
      return;
    }
    deliver(topics);
  }

  function initializeResult(params) {
    return {
      protocolVersion: (params && params.protocolVersion) || "2026-01-26",
      hostInfo: { name: "recording-studio-dummy", version: "0.1.0" },
      hostCapabilities: {
        serverTools: { listChanged: true },
        updateModelContext: { text: {}, structuredContent: {} }
      },
      hostContext: {}
    };
  }

  window.addEventListener("message", function (event) {
    if (event.source !== frame.contentWindow) return;
    var message = event.data;
    if (!message || message.jsonrpc !== "2.0" || !message.method) return;

    if (message.method === "ui/initialize") {
      event.source.postMessage({
        jsonrpc: "2.0",
        id: message.id,
        result: initializeResult(message.params)
      }, "*");
      ready = true;
      if (queued) {
        var topics = queued;
        queued = null;
        setTimeout(function () { deliver(topics); }, 0);
      }
    }
  });

  document.getElementById("topics-show").addEventListener("click", function () {
    publish(["Launch", "Story", "Press"]);
  });

  document.getElementById("topics-clear").addEventListener("click", function () {
    publish([]);
  });
})();
