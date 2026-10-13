(function (root) {
  "use strict";

  var fieldsWarned = false;

  function fieldsApi() {
    var api = root.McpFields;
    if (fieldsReady(api)) return api;
    if (!fieldsWarned) {
      fieldsWarned = true;
      if (root.console && typeof root.console.error === "function") {
        root.console.error(
          "Recording Studio MCP UI: window.McpFields is missing. Load controllers/editor_controller.js before boot.js."
        );
      }
    }
    return null;
  }

  function fieldsReady(api) {
    return !!api &&
      typeof api.own === "function" &&
      typeof api.inputType === "function" &&
      typeof api.writeField === "function" &&
      typeof api.inputFieldKey === "function";
  }

  function bindText(data) {
    var api = fieldsApi();
    var nodes = document.querySelectorAll("[data-mcp-text]");
    Array.prototype.forEach.call(nodes, function (node) {
      if (insideListEntry(node)) return;
      var field = node.getAttribute("data-mcp-text");
      if (!field || !api || !api.own(data, field) || data[field] == null) return;
      node.textContent = data[field];
    });
  }

  function insideListEntry(node) {
    return typeof node.closest === "function" && !!node.closest("[data-mcp-list-entry]");
  }

  function listItems(data, key) {
    var api = fieldsApi();
    if (!api || !data || typeof data !== "object" || Array.isArray(data)) return [];
    if (!api.own(data, key)) return [];
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

  function scalarItem(item) {
    var kind = typeof item;
    return kind === "string" || kind === "number" || kind === "boolean";
  }

  function templateAcceptsScalar(template) {
    var bare = false;
    var named = false;
    clonedElements(template).forEach(function (node) {
      elementsWithin(node).forEach(function (element) {
        if (!element.hasAttribute("data-mcp-text")) return;
        if (element.getAttribute("data-mcp-text")) named = true;
        else bare = true;
      });
    });
    return bare && !named;
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
    var api = fieldsApi();
    if (!api || !itemRecord(item)) return;
    var inputs = [];
    if (node.hasAttribute("data-mcp-field")) inputs.push(node);
    Array.prototype.forEach.call(node.querySelectorAll("[data-mcp-field]"), function (input) {
      inputs.push(input);
    });
    inputs.forEach(function (input) {
      var key = api.inputFieldKey(input);
      if (!key || !api.own(item, key)) return;
      api.writeField(input, item[key]);
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

  function allowedUrl(value) {
    var text = String(value == null ? "" : value);
    var stripped = "";
    for (var i = 0; i < text.length; i++) {
      var code = text.charCodeAt(i);
      if (code <= 32 || code === 127) continue;
      stripped += text.charAt(i);
    }
    if (!stripped) return true;
    if (stripped.charAt(0) === "\\") return false;
    if (stripped.slice(0, 2) === "//") return false;
    var match = /^([a-zA-Z][a-zA-Z0-9+.-]*):/.exec(stripped);
    if (!match) return true;
    var scheme = match[1].toLowerCase();
    return scheme === "http" || scheme === "https" || scheme === "mailto";
  }

  function stimulusAttribute(name) {
    return name === "data-controller" || name === "data-action" || name.slice(-7) === "-target";
  }

  function assignAttribute(element, htmlName, value) {
    var name = String(htmlName || "").toLowerCase();
    if (!name || name.indexOf("on") === 0 || name === "style" || name === "srcdoc") return;
    if (stimulusAttribute(name)) {
      element.removeAttribute(name);
      return;
    }
    var url = name === "href" || name === "src";
    var plain = name === "id" || name === "class" || name === "title" || name === "value" ||
      name.indexOf("data-") === 0 || name.indexOf("aria-") === 0;
    if (!plain && !url) return;
    if (url && !allowedUrl(value)) return;
    element.setAttribute(name, value);
  }

  function fillAttributes(node, item, index) {
    elementsWithin(node).forEach(function (element) {
      attributeNames(element).slice().forEach(function (name) {
        if (name.indexOf("data-mcp-attr-") !== 0) return;
        var htmlName = name.slice("data-mcp-attr-".length);
        if (!htmlName) return;
        assignAttribute(element, htmlName, attributeValue(element.getAttribute(name), item, index));
      });
    });
  }

  function fillItem(node, item, index) {
    fillText(node, item);
    fillFields(node, item);
    fillAttributes(node, item, index);
  }

  function owned(list, selector) {
    var found = [];
    Array.prototype.forEach.call(list.querySelectorAll(selector), function (node) {
      if (node === list) return;
      if (typeof node.closest === "function" && node.closest("[data-mcp-list]") === list) found.push(node);
    });
    return found;
  }

  function toggleEmpty(list, isEmpty) {
    owned(list, "[data-mcp-list-empty]").forEach(function (empty) {
      if (isEmpty) empty.removeAttribute("hidden");
      else empty.setAttribute("hidden", "");
    });
  }

  function clonedElements(template) {
    var fragment = template.content.cloneNode(true);
    var nodes = [];
    Array.prototype.forEach.call(fragment.childNodes, function (node) {
      if (node.nodeType === 1) nodes.push(node);
    });
    return nodes;
  }

  function itemKey(item) {
    var api = fieldsApi();
    if (!api || !itemRecord(item) || !api.own(item, "id") || item.id == null) return "";
    var text = String(item.id);
    return text ? text : "";
  }

  function entryPools(entries) {
    var pools = Object.create(null);
    entries.forEach(function (entry) {
      var key = entry.getAttribute("data-mcp-list-key");
      if (!key) return;
      if (!pools[key]) pools[key] = [];
      pools[key].push(entry);
    });
    return pools;
  }

  function nodesFor(template, pools, item, index, refill) {
    var key = itemKey(item);
    var clones = clonedElements(template);
    var bucket = key && pools[key] ? pools[key] : null;
    if (bucket && clones.length && bucket.length >= clones.length) {
      var reused = bucket.splice(0, clones.length);
      reused.forEach(function (node) {
        fillText(node, item);
        fillAttributes(node, item, index);
        if (refill) fillFields(node, item);
      });
      return reused;
    }
    clones.forEach(function (node) {
      node.setAttribute("data-mcp-list-entry", "");
      if (key) node.setAttribute("data-mcp-list-key", key);
      fillItem(node, item, index);
    });
    return clones;
  }

  function bindList(list, data, refill) {
    var template = owned(list, "template[data-mcp-list-item]")[0];
    if (!template || !template.content || typeof template.content.cloneNode !== "function") return;
    var items = listItems(data, list.getAttribute("data-mcp-list") || "");
    var scalars = templateAcceptsScalar(template);
    var kept = [];
    items.forEach(function (item) {
      if (itemRecord(item) || (scalars && scalarItem(item))) kept.push(item);
    });
    var pools = entryPools(owned(list, "[data-mcp-list-entry]"));
    var live = [];
    kept.forEach(function (item, index) {
      nodesFor(template, pools, item, index, refill).forEach(function (node) {
        if (template.parentNode) template.parentNode.insertBefore(node, template);
        live.push(node);
      });
    });
    owned(list, "[data-mcp-list-entry]").forEach(function (node) {
      if (live.indexOf(node) === -1) node.remove();
    });
    toggleEmpty(list, kept.length === 0);
  }

  function bindLists(data, meta) {
    var refill = !!(meta && meta.reset);
    Array.prototype.forEach.call(document.querySelectorAll("[data-mcp-list]"), function (list) {
      bindList(list, data, refill);
    });
  }

  function bindWidget(data) {
    bindText(data);
    bindLists(data);
  }

  function boot() {
    if (!root.mcpUI) return;
    fieldsApi();
    root.mcpUI.onData(function (data, meta) {
      bindText(data);
      if (!meta || meta.dataChanged) bindLists(data, meta);
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
