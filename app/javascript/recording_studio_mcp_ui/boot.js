(function (root) {
  "use strict";

  function bindText(data) {
    var nodes = document.querySelectorAll("[data-mcp-text]");
    Array.prototype.forEach.call(nodes, function (node) {
      var field = node.getAttribute("data-mcp-text");
      if (field && data && data[field] != null) node.textContent = data[field];
    });
  }

  function boot() {
    if (!root.mcpUI) return;
    root.mcpUI.onData(function (data) {
      bindText(data);
    });
    root.mcpUI.start().then(function () {
      bindText(root.mcpUI.data());
      var roots = document.querySelectorAll("[data-controller~='mcp-editor']");
      Array.prototype.forEach.call(roots, function (node) {
        if (root.McpEditorController) root.McpEditorController.connect(node);
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})(window);
