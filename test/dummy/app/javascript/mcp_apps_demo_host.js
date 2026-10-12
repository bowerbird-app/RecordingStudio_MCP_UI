(function () {
  "use strict";

  var csrf = document.querySelector("meta[name='csrf-token']");
  var csrfToken = csrf ? csrf.content : "";

  function frameFor(source) {
    var frames = document.querySelectorAll("iframe[data-save-url]");
    for (var i = 0; i < frames.length; i++) {
      if (frames[i].contentWindow === source) return frames[i];
    }
    return null;
  }

  function reply(source, id, result) {
    source.postMessage({ jsonrpc: "2.0", id: id, result: result }, "*");
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
    var frame = frameFor(event.source);
    if (!frame) return;
    var message = event.data;
    if (!message || message.jsonrpc !== "2.0" || !message.method) return;

    if (message.method === "ui/initialize") {
      reply(event.source, message.id, initializeResult(message.params));
      return;
    }

    if (message.method === "tools/call") {
      var recordId = frame.getAttribute("data-record-id") || frame.getAttribute("data-project-id");
      var args = Object.assign({}, (message.params && message.params.arguments) || {}, { id: recordId });
      fetch(frame.getAttribute("data-save-url"), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify(args)
      }).then(function (response) {
        return response.json().then(function (body) {
          reply(event.source, message.id, { content: [], structuredContent: body });
        });
      }).catch(function (error) {
        event.source.postMessage({
          jsonrpc: "2.0",
          id: message.id,
          error: { code: -32000, message: String(error) }
        }, "*");
      });
      return;
    }

    if (message.method === "ui/update-model-context" && message.id !== undefined) {
      reply(event.source, message.id, {});
    }
  });
})();
