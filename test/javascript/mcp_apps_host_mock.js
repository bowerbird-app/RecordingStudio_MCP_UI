function initializeResult(params) {
  return {
    protocolVersion: (params && params.protocolVersion) || "2026-01-26",
    hostInfo: { name: "recording-studio-js-test", version: "0.1.0" },
    hostCapabilities: {
      serverTools: { listChanged: true },
      updateModelContext: { text: {}, structuredContent: {} }
    },
    hostContext: {}
  };
}

function attachMockHost(windowLike, { onToolCall } = {}) {
  const listeners = [];
  const parent = {
    postMessage(message) {
      queueMicrotask(() => {
        let reply = null;
        if (message.method === "ui/initialize") {
          reply = { jsonrpc: "2.0", id: message.id, result: initializeResult(message.params) };
        } else if (message.method === "tools/call") {
          const payload = onToolCall ? onToolCall(message.params) : { ok: true, data: {} };
          reply = {
            jsonrpc: "2.0",
            id: message.id,
            result: { content: [], structuredContent: payload }
          };
        } else if (message.method === "ui/update-model-context") {
          reply = { jsonrpc: "2.0", id: message.id, result: {} };
        }
        if (!reply) return;
        listeners.forEach((listener) => listener({ data: reply, source: parent }));
      });
    }
  };

  windowLike.parent = parent;
  windowLike.addEventListener = function (name, fn) {
    if (name === "message") listeners.push(fn);
  };
  windowLike.removeEventListener = function (name, fn) {
    if (name !== "message") return;
    const index = listeners.indexOf(fn);
    if (index >= 0) listeners.splice(index, 1);
  };
  return parent;
}

module.exports = { attachMockHost };
