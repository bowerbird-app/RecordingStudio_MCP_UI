(function (root) {
  "use strict";

  function q(rootEl, selector) {
    return rootEl.querySelector(selector);
  }

  function all(rootEl, selector) {
    return Array.prototype.slice.call(rootEl.querySelectorAll(selector));
  }

  function bindField(input, data) {
    var name = input.getAttribute("name") || input.dataset.field;
    if (!name) return;
    if (input.type === "checkbox") {
      input.checked = !!data[name];
    } else if (data[name] != null) {
      input.value = data[name];
    }
  }

  function collect(rootEl) {
    var payload = {};
    all(rootEl, "[data-mcp-field]").forEach(function (input) {
      var name = input.getAttribute("name") || input.dataset.field;
      if (!name) return;
      payload[name] = input.type === "checkbox" ? input.checked : input.value;
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

  function connect(rootEl) {
    if (!root.mcpUI) return;

    setErrors(rootEl, {});
    setStatus(rootEl, "", "");
    Object.keys(root.mcpUI.data()).forEach(function () {});
    all(rootEl, "[data-mcp-field]").forEach(function (input) {
      bindField(input, root.mcpUI.data());
      input.addEventListener("input", function () {
        root.mcpUI.markDirty();
        rootEl.classList.add("is-dirty");
      });
      input.addEventListener("change", function () {
        root.mcpUI.markDirty();
        rootEl.classList.add("is-dirty");
      });
    });

    root.mcpUI.onData(function (data, meta) {
      all(rootEl, "[data-mcp-field]").forEach(function (input) {
        if (document.activeElement === input && meta.dirty) return;
        bindField(input, data);
      });
      all(rootEl, "[data-mcp-text]").forEach(function (node) {
        var field = node.getAttribute("data-mcp-text");
        if (data[field] != null) node.textContent = data[field];
      });
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

  root.McpEditorController = { connect: connect };
})(window);
