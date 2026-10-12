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

  function itemRecord(item) {
    return !!item && typeof item === "object" && !Array.isArray(item);
  }

  function itemFieldName(name) {
    if (!name) return "";
    var marker = "[][";
    var at = name.lastIndexOf(marker);
    if (at === -1) return name;
    var inner = name.slice(at + marker.length);
    if (!inner || inner.charAt(inner.length - 1) !== "]") return name;
    inner = inner.slice(0, -1);
    if (!inner || inner.indexOf("[") !== -1 || inner.indexOf("]") !== -1) return name;
    return inner;
  }

  function fieldKey(input) {
    var named = input.getAttribute("name") || "";
    if (named) return itemFieldName(named);
    var marked = input.getAttribute("data-mcp-field") || "";
    if (!marked || marked === "true") return "";
    return itemFieldName(marked);
  }

  function controlType(input) {
    var typed = input.type || (input.getAttribute && input.getAttribute("type")) || "";
    return String(typed).toLowerCase();
  }

  function controlValue(input) {
    if (input.value != null && String(input.value) !== "") return String(input.value);
    var attr = input.getAttribute && input.getAttribute("value");
    return attr == null ? "" : String(attr);
  }

  function assignFieldValue(input, value) {
    var type = controlType(input);
    if (type === "button" || type === "submit" || type === "reset" || type === "file") return;
    if (type === "checkbox") {
      input.checked = value === true || value === "true" || value === "1" || value === 1;
      return;
    }
    if (type === "radio") {
      input.checked = value != null && controlValue(input) === String(value);
      return;
    }
    if (value == null) {
      input.value = "";
      return;
    }
    input.value = typeof value === "object" ? JSON.stringify(value) : String(value);
  }

  function fillText(node, item) {
    var slots = [];
    if (node.hasAttribute("data-mcp-text")) slots.push(node);
    Array.prototype.forEach.call(node.querySelectorAll("[data-mcp-text]"), function (slot) {
      slots.push(slot);
    });
    slots.forEach(function (slot) {
      slot.textContent = textForSlot(item, slot.getAttribute("data-mcp-text") || "");
    });
  }

  function fillFields(node, item) {
    if (!itemRecord(item)) return;
    var inputs = [];
    if (node.hasAttribute("data-mcp-field")) inputs.push(node);
    Array.prototype.forEach.call(node.querySelectorAll("[data-mcp-field]"), function (input) {
      inputs.push(input);
    });
    inputs.forEach(function (input) {
      var key = fieldKey(input);
      if (!key || !Object.prototype.hasOwnProperty.call(item, key)) return;
      assignFieldValue(input, item[key]);
    });
  }

  function attributeNames(node) {
    if (node.attributes && typeof node.attributes.length === "number") {
      var names = [];
      for (var i = 0; i < node.attributes.length; i++) {
        if (node.attributes[i] && node.attributes[i].name) names.push(node.attributes[i].name);
      }
      return names;
    }
    if (node.attrs) return Object.keys(node.attrs);
    return [];
  }

  function elementsWithin(node) {
    var found = [];
    walk(node);
    return found;

    function walk(current) {
      if (!current || current.nodeType !== 1) return;
      found.push(current);
      if (current.tagName === "TEMPLATE") return;
      var children = current.childNodes || [];
      for (var i = 0; i < children.length; i++) walk(children[i]);
    }
  }

  function attributeValue(source, item, index) {
    var text = source == null ? "" : String(source);
    if (text.indexOf("$index") !== -1) return text.split("$index").join(String(index));
    return textForSlot(item, text);
  }

  function fillAttributes(node, item, index) {
    elementsWithin(node).forEach(function (element) {
      attributeNames(element).slice().forEach(function (name) {
        if (name.indexOf("data-mcp-attr-") !== 0) return;
        var htmlName = name.slice("data-mcp-attr-".length);
        if (!htmlName) return;
        element.setAttribute(htmlName, attributeValue(element.getAttribute(name), item, index));
      });
    });
  }

  function fillItem(node, item, index) {
    fillText(node, item);
    fillFields(node, item);
    fillAttributes(node, item, index);
  }

  function clearEntries(list) {
    [ "[data-mcp-list-entry]", "[data-mcp-row]" ].forEach(function (selector) {
      Array.prototype.forEach.call(list.querySelectorAll(selector), function (node) {
        if (node === list) return;
        if (typeof node.closest === "function" && node.closest("[data-mcp-list]") === list) node.remove();
      });
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
    items.forEach(function (item, index) {
      clonedElements(template).forEach(function (node) {
        node.setAttribute("data-mcp-list-entry", "");
        fillItem(node, item, index);
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
