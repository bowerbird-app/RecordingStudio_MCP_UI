(function (root) {
  "use strict";

  function boot() {
    if (!root.mcpUI) return;
    root.mcpUI.start().then(function () {
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
