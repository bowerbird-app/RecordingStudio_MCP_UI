(function (root) {
  "use strict";

  function bindText(data) {
    var nodes = document.querySelectorAll("[data-mcp-text]");
    Array.prototype.forEach.call(nodes, function (node) {
      var field = node.getAttribute("data-mcp-text");
      if (field && data && data[field] != null) node.textContent = data[field];
    });
  }

  function ownValue(data, field) {
    if (!field || !data || typeof data !== "object") return undefined;
    if (!Object.prototype.hasOwnProperty.call(data, field)) return undefined;
    return data[field];
  }

  function bindLinks(data) {
    var nodes = document.querySelectorAll("[data-mcp-link-field]");
    Array.prototype.forEach.call(nodes, function (node) {
      if (!node.setAttribute) return;
      var value = ownValue(data, node.getAttribute("data-mcp-link-field"));
      if (typeof value === "string") {
        node.setAttribute("data-mcp-link", value);
      } else if (node.removeAttribute) {
        node.removeAttribute("data-mcp-link");
      }
    });
  }

  function paint(data) {
    bindText(data);
    bindLinks(data);
  }

  function urlFromLinkNode(node) {
    var explicit = node.getAttribute("data-mcp-link");
    if (explicit) return explicit;
    var tag = String(node.tagName || node.nodeName || "").toUpperCase();
    if (tag === "A") return node.getAttribute("href") || "";
    return "";
  }

  function onLinkClick(event) {
    var target = event && event.target;
    if (!target || typeof target.closest !== "function") return;
    var node = target.closest("[data-mcp-link]");
    if (!node || !root.mcpUI || typeof root.mcpUI.openLink !== "function") return;
    if (event.preventDefault) event.preventDefault();
    root.mcpUI.openLink(urlFromLinkNode(node)).catch(function () {
      return null;
    });
  }

  function boot() {
    if (!root.mcpUI) return;
    if (document.addEventListener) document.addEventListener("click", onLinkClick);
    root.mcpUI.onData(function (data) {
      paint(data);
    });
    root.mcpUI.start().then(function () {
      paint(root.mcpUI.data());
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
