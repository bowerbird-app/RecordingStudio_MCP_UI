(function (root) {
  "use strict";

  function bindText(data) {
    var nodes = document.querySelectorAll("[data-mcp-text]");
    Array.prototype.forEach.call(nodes, function (node) {
      if (insideListEntry(node)) return;
      var field = node.getAttribute("data-mcp-text");
      if (field && data && data[field] != null) node.textContent = data[field];
    });
  }

  function insideListEntry(node) {
    return typeof node.closest === "function" && !!node.closest("[data-mcp-list-entry]");
  }

  function listItems(data, key) {
    if (!data || typeof data !== "object") return [];
    var value = data[key];
    return Array.isArray(value) ? value : [];
  }

  function textForSlot(item, field) {
    if (typeof item === "string" || typeof item === "number" || typeof item === "boolean") {
      return field ? "" : String(item);
    }
    if (!item || typeof item !== "object" || Array.isArray(item)) return "";
    if (!field || !Object.prototype.hasOwnProperty.call(item, field)) return "";
    var value = item[field];
    if (value == null || typeof value === "object") return "";
    return String(value);
  }

  function fillItem(node, item) {
    var slots = [];
    if (node.hasAttribute("data-mcp-text")) slots.push(node);
    Array.prototype.forEach.call(node.querySelectorAll("[data-mcp-text]"), function (slot) {
      slots.push(slot);
    });
    slots.forEach(function (slot) {
      slot.textContent = textForSlot(item, slot.getAttribute("data-mcp-text") || "");
    });
  }

  function clearEntries(list) {
    Array.prototype.forEach.call(list.querySelectorAll("[data-mcp-list-entry]"), function (node) {
      if (typeof node.closest === "function" && node.closest("[data-mcp-list]") === list) node.remove();
    });
  }

  function toggleEmpty(list, isEmpty) {
    var empty = list.querySelector("[data-mcp-list-empty]");
    if (!empty) return;
    if (isEmpty) empty.removeAttribute("hidden");
    else empty.setAttribute("hidden", "");
  }

  function clonedElements(template) {
    var fragment = template.content.cloneNode(true);
    var nodes = [];
    Array.prototype.forEach.call(fragment.childNodes, function (node) {
      if (node.nodeType === 1) nodes.push(node);
    });
    return nodes;
  }

  function bindList(list, data) {
    var template = list.querySelector("template[data-mcp-list-item]");
    if (!template || !template.content || typeof template.content.cloneNode !== "function") return;
    var items = listItems(data, list.getAttribute("data-mcp-list") || "");
    clearEntries(list);
    items.forEach(function (item) {
      clonedElements(template).forEach(function (node) {
        node.setAttribute("data-mcp-list-entry", "");
        fillItem(node, item);
        if (template.parentNode) template.parentNode.insertBefore(node, template);
      });
    });
    toggleEmpty(list, items.length === 0);
  }

  function bindLists(data) {
    Array.prototype.forEach.call(document.querySelectorAll("[data-mcp-list]"), function (list) {
      bindList(list, data);
    });
  }

  function bindWidget(data) {
    bindText(data);
    bindLists(data);
  }

  function boot() {
    if (!root.mcpUI) return;
    root.mcpUI.onData(function (data, meta) {
      bindText(data);
      if (!meta || meta.dataChanged) bindLists(data);
    });
    root.mcpUI.start().then(function () {
      bindWidget(root.mcpUI.data());
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
