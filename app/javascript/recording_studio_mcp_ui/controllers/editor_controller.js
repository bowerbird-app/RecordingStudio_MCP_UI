(function (root) {
  "use strict";

  var ROW_SELECTOR = "[data-mcp-row], [data-collection-editor-row], tr, li";

  function q(rootEl, selector) {
    return rootEl.querySelector(selector);
  }

  function all(rootEl, selector) {
    return Array.prototype.slice.call(rootEl.querySelectorAll(selector));
  }

  function fieldName(input) {
    var named = input.getAttribute && input.getAttribute("name");
    if (named) return named;
    return (input.dataset && input.dataset.field) || "";
  }

  function inputType(input) {
    return String(input.type || "").toLowerCase();
  }

  function mcpType(input) {
    var typed = input.getAttribute && input.getAttribute("data-mcp-type");
    return typed ? String(typed).toLowerCase() : "";
  }

  function bindable(input) {
    var type = inputType(input);
    return type !== "button" && type !== "submit" && type !== "reset" && type !== "file";
  }

  function collectable(input) {
    if (!bindable(input) || input.disabled) return false;
    return inputType(input) !== "radio" || input.checked;
  }

  function typedValue(input) {
    var kind = mcpType(input);
    if (!kind) return undefined;
    var raw = input.value == null ? "" : String(input.value);
    if (raw === "") {
      if (kind === "array") return [];
      if (kind === "object") return {};
      return null;
    }
    try {
      var parsed = JSON.parse(raw);
      if (kind === "array" && !Array.isArray(parsed)) return raw;
      if (kind === "object" && (!parsed || typeof parsed !== "object" || Array.isArray(parsed))) return raw;
      return parsed;
    } catch (error) {
      return raw;
    }
  }

  function fieldValue(input) {
    if (inputType(input) === "checkbox") return !!input.checked;
    var typed = typedValue(input);
    if (typed !== undefined) return typed;
    return input.value;
  }

  function isHash(value) {
    return !!value && typeof value === "object" && !Array.isArray(value);
  }

  function splitName(name, depth) {
    if (name == null) return { key: "", after: "" };
    if (depth === 0) {
      var start = name.indexOf("[", 1);
      if (start === -1) return { key: name, after: "" };
      return { key: name.slice(0, start), after: name.slice(start) };
    }
    if (name.indexOf("[]") === 0) return { key: "[]", after: name.slice(2) };
    if (name.charAt(0) === "[") {
      var end = name.indexOf("]", 1);
      if (end !== -1) return { key: name.slice(1, end), after: name.slice(end + 1) };
    }
    return { key: name, after: "" };
  }

  function childKeyFor(after) {
    if (after.charAt(2) === "[" && after.charAt(after.length - 1) === "]") {
      var inner = after.slice(3, after.length - 1);
      if (inner && inner.indexOf("[") === -1 && inner.indexOf("]") === -1) return inner;
    }
    return after.slice(2);
  }

  function hashHasKey(hash, key) {
    if (/\[\]/.test(key)) return false;
    var parts = key.split(/[\[\]]+/);
    var current = hash;
    for (var i = 0; i < parts.length; i++) {
      var part = parts[i];
      if (!part) continue;
      if (!isHash(current) || !Object.prototype.hasOwnProperty.call(current, part)) return false;
      current = current[part];
    }
    return true;
  }

  function normalize(params, name, value, depth) {
    if (depth > 32) return params;
    var parts = splitName(name, depth);
    var key = parts.key;
    var after = parts.after;
    if (!key) return params;
    if (after === "") {
      if (key === "[]" && depth !== 0) return [value];
      params[key] = value;
      return params;
    }
    if (after === "[") {
      params[name] = value;
      return params;
    }
    if (after === "[]") {
      if (!Array.isArray(params[key])) params[key] = [];
      params[key].push(value);
      return params;
    }
    if (after.indexOf("[]") === 0) return nestArray(params, key, after, value, depth);
    if (!isHash(params[key])) params[key] = {};
    normalize(params[key], after, value, depth + 1);
    return params;
  }

  function nestArray(params, key, after, value, depth) {
    var childKey = childKeyFor(after);
    if (!Array.isArray(params[key])) params[key] = [];
    var list = params[key];
    var last = list[list.length - 1];
    if (isHash(last) && !hashHasKey(last, childKey)) {
      normalize(last, childKey, value, depth + 1);
    } else {
      list.push(normalize({}, childKey, value, depth + 1));
    }
    return params;
  }

  function assignParam(params, name, value) {
    normalize(params, name, value, 0);
  }

  function assignTracking(params, name, token, depth, trail) {
    var parts = splitName(name, depth);
    var key = parts.key;
    var after = parts.after;
    if (!key) return;
    if (after === "") {
      token.path = trail.concat(key === "[]" && depth !== 0 ? 0 : key);
      params[key] = token;
      return;
    }
    if (after === "[]") {
      if (!Array.isArray(params[key])) params[key] = [];
      token.path = trail.concat(key, params[key].length);
      params[key].push(token);
      return;
    }
    if (after.indexOf("[]") === 0) {
      trackArray(params, key, after, token, depth, trail);
      return;
    }
    if (!isHash(params[key])) params[key] = {};
    assignTracking(params[key], after, token, depth + 1, trail.concat(key));
  }

  function trackArray(params, key, after, token, depth, trail) {
    var childKey = childKeyFor(after);
    if (!Array.isArray(params[key])) params[key] = [];
    var list = params[key];
    var last = list[list.length - 1];
    if (!(isHash(last) && !hashHasKey(last, childKey))) {
      last = {};
      list.push(last);
    }
    assignTracking(last, childKey, token, depth + 1, trail.concat(key, list.length - 1));
  }

  function trackPaths(fields) {
    var params = {};
    return fields.map(function (input) {
      var name = fieldName(input);
      if (!name || name.indexOf("[") === -1) return null;
      var token = { path: null };
      assignTracking(params, name, token, 0, []);
      return token.path;
    });
  }

  function dig(data, path) {
    var current = data;
    if (!path) return undefined;
    for (var i = 0; i < path.length; i++) {
      if (current == null) return undefined;
      current = current[path[i]];
    }
    return current;
  }

  function writeField(input, value) {
    var type = inputType(input);
    if (type === "checkbox") {
      input.checked = !!value;
      return;
    }
    if (type === "radio") {
      input.checked = value != null && String(input.value) === String(value);
      return;
    }
    if (mcpType(input)) {
      input.value = value == null ? "" : (typeof value === "string" ? value : JSON.stringify(value));
      return;
    }
    if (value != null) input.value = String(value);
  }

  function bindField(input, data, path) {
    var name = fieldName(input);
    if (!name) return;
    var structured = name.indexOf("[") !== -1 || mcpType(input);
    var value = structured ? (path ? dig(data, path) : data[name]) : data[name];
    writeField(input, value);
  }

  function bindFields(rootEl, data) {
    var fields = all(rootEl, "[data-mcp-field]").filter(bindable);
    var paths = trackPaths(fields);
    fields.forEach(function (input, index) {
      bindField(input, data, paths[index]);
    });
  }

  function collect(rootEl) {
    var payload = {};
    all(rootEl, "[data-mcp-field]").forEach(function (input) {
      var name = fieldName(input);
      if (!name || !collectable(input)) return;
      var value = fieldValue(input);
      if (name.indexOf("[") === -1) payload[name] = value;
      else assignParam(payload, name, value);
    });
    return payload;
  }

  function setStatus(rootEl, kind, message) {
    var node = q(rootEl, "[data-mcp-status]");
    if (!node) return;
    node.dataset.kind = kind || "";
    node.textContent = message || "";
    node.hidden = !message;
  }

  function setErrors(rootEl, errors) {
    all(rootEl, "[data-mcp-error]").forEach(function (node) {
      var field = node.getAttribute("data-mcp-error");
      var message = errors && errors[field];
      node.textContent = message || "";
      node.hidden = !message;
    });
  }

  function setBusy(rootEl, busy) {
    rootEl.classList.toggle("is-saving", !!busy);
    all(rootEl, "[data-mcp-save]").forEach(function (button) {
      button.disabled = !!busy;
    });
  }

  function markEdited(rootEl) {
    root.mcpUI.markDirty();
    rootEl.classList.add("is-dirty");
  }

  function rowFor(input) {
    if (!input.closest) return null;
    var name = fieldName(input);
    if (!name || name.indexOf("[]") === -1) return null;
    return input.closest(ROW_SELECTOR);
  }

  function rememberOrder(rootEl) {
    var groups = [];
    all(rootEl, "[data-mcp-field]").forEach(function (input) {
      var row = rowFor(input);
      if (!row || !row.parentNode) return;
      var group = groups.filter(function (item) { return item.parent === row.parentNode; })[0];
      if (!group) {
        group = { parent: row.parentNode, rows: [], marker: null };
        groups.push(group);
      }
      if (group.rows.indexOf(row) === -1) group.rows.push(row);
    });
    groups.forEach(placeMarker);
    return groups;
  }

  function placeMarker(group) {
    var parent = group.parent;
    var documentRef = parent.ownerDocument;
    if (!documentRef || !documentRef.createComment || !parent.insertBefore) return;
    var marker = documentRef.createComment("mcp-ui-order");
    parent.insertBefore(marker, group.rows[0] || null);
    group.marker = marker;
  }

  function restoreOrder(groups) {
    groups.forEach(function (group) {
      var parent = group.parent;
      var marker = group.marker;
      if (!parent || !parent.insertBefore || !marker || marker.parentNode !== parent) return;
      group.rows.forEach(function (row) {
        parent.insertBefore(row, marker);
      });
    });
  }

  function sameRecord(data) {
    return data === root.mcpUI.config().data;
  }

  function connect(rootEl) {
    if (!root.mcpUI) return;
    var orderGroups = rememberOrder(rootEl);

    setErrors(rootEl, {});
    setStatus(rootEl, "", "");
    bindFields(rootEl, root.mcpUI.data());
    all(rootEl, "[data-mcp-field]").forEach(function (input) {
      input.addEventListener("input", function () { markEdited(rootEl); });
      input.addEventListener("change", function () { markEdited(rootEl); });
    });
    if (typeof rootEl.addEventListener === "function") {
      rootEl.addEventListener("input", function (event) { delegateEdit(rootEl, event); });
      rootEl.addEventListener("change", function (event) { delegateEdit(rootEl, event); });
    }

    root.mcpUI.onData(function (data, meta) {
      if (meta.dataChanged) {
        if (sameRecord(data)) restoreOrder(orderGroups);
        bindFields(rootEl, data);
      }
      rootEl.classList.toggle("is-dirty", !!meta.dirty);
    });

    all(rootEl, "[data-mcp-save]").forEach(function (button) {
      button.addEventListener("click", function () {
        setBusy(rootEl, true);
        setErrors(rootEl, {});
        setStatus(rootEl, "loading", "Saving…");
        root.mcpUI.execute(button.getAttribute("data-mcp-save") || "save", collect(rootEl)).then(function () {
          setStatus(rootEl, "success", "Saved");
        }).catch(function (error) {
          setErrors(rootEl, (error && error.errors) || {});
          setStatus(rootEl, "error", (error && (error.error || error.message)) || "Save failed");
        }).then(function () {
          setBusy(rootEl, false);
        });
      });
    });

    all(rootEl, "[data-mcp-reset]").forEach(function (button) {
      button.addEventListener("click", function () {
        root.mcpUI.reset();
        setErrors(rootEl, {});
        setStatus(rootEl, "", "");
      });
    });
  }

  function delegateEdit(rootEl, event) {
    var target = event && event.target;
    if (!target || !target.closest) return;
    var field = target.closest("[data-mcp-field]");
    if (!field) return;
    if (rootEl.contains && !rootEl.contains(field)) return;
    markEdited(rootEl);
  }

  root.McpEditorController = { connect: connect };
})(window);
