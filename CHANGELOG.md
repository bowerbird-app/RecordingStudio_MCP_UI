# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Dummy page widgets fill from the tool result. Topic chips, the outline, section rows, and link rows are `data-mcp-list` templates. `resources/read` packages them empty. The tool result clones the FlatPack row and sets its fields. Notes use the stock accordion, which has no item template.
- A saved page link accepts an `http`, `https`, or relative URL. Other schemes are rejected.
- Dummy section rows, including the add-row template, opt in with `data-mcp-row`. The sections editor sets `data-mcp-restore-order`. Link rows opt in with `data-mcp-row` on the template `<tr>` and use FlatPack text inputs named `links[][label]` and `links[][url]`. The row template is a table-sortable target, so a filled list refreshes that controller and the new rows can be dragged. The links editor leaves order alone on refresh, because Save returns the new DOM order. The links document sorts that array into the header order before packaging.
- Dummy Page demo packages a collection editor, a links table with one reorder grip per row, tabs, topic chips, and an accordion. The dummy `widget_script_path` points at the esbuild bundle that registers those controllers.
- Dummy project editor sits in a FlatPack card: page title in the header, fields and Save/Cancel in the body.
- Dummy widget controls are FlatPack components. Project title is a text input and description is a textarea. Error and status lines are alerts. Preview text is Content and a badge. The page story title binds with `data-mcp-text="title"`. Outline and topic empty states use List or EmptyState. Link cells and section fields are text inputs. Topic chips are static.

## [0.4.0] - 2026-10-12

### Added
- Display lists in the packaged runtime. A container uses `data-mcp-list`, one item lives in `<template data-mcp-list-item>`, and the empty state uses `data-mcp-list-empty`. An empty `data-mcp-text` fills a scalar. A named `data-mcp-text` fills that field on an object. Both reads use own properties only. Items that are not plain objects are skipped, except a string, number, or boolean in a scalar template, so nulls, arrays, and stray values do not become blank rows.
- The same clone fills `[data-mcp-field]` through the editor's field writer and keeps the input `name`, so a template row can save `links[][label]` in DOM order. `[data-mcp-row]` marks that row. The name parser is the editor's `place` parser.
- `data-mcp-attr-<name>` sets one allowlisted attribute from a field or from `$index` (`note-$index-content`). Allowed names are `id`, `class`, `title`, `value`, `data-*`, and `aria-*`. `href` and `src` are written only for `http:`, `https:`, `mailto:`, or a relative URL. `data-controller`, `data-action`, and any name ending in `-target` are not written. The name check is case-insensitive.
- `editor_controller.js` assigns `window.McpFields` (`own`, `inputType`, `writeField`, `inputFieldKey`). `boot.js` reads it. `Assets::RUNTIME_JS` concatenates the editor file before `boot.js`. A missing export logs one error and still starts the host connection.

### Changed
- `mcpUI.reset()` restores the first non-blank record. An empty `resources/read` package resets to the tool result that opened the widget. A package that already had data still resets to that data. `onData` receives `reset: true` for that call, and a reused list row is filled from that record again.
- `data-mcp-restore-order` moves only rows that are still in their parent and are not list clones. List clones stay in the order the binder placed them.
- A later tool result removes only `[data-mcp-list-entry]` clones for that list. Rows a collection editor added stay. The empty toggle ignores a nested list. An item `id` reuses the previous clone, keeps unsaved input values, and refreshes text and allowlisted attributes.
- When every row in a result is a new clone, a clone that carries `data-<identifier>-target` causes that identifier's `data-controller` token to be removed and restored on the next microtask. Stimulus disconnects and connects the controller. A result that reuses a row does not touch the token, so listeners are not added again.

### Upgrade notes
- Put repeating rows in the list template. `resources/read` packages with no data, so a Ruby loop cannot show the tool result. Keep `data-mcp-field` names such as `sections[][heading]` and mark the row `data-mcp-row`. Give items an `id` when a later result should keep unsaved edits on that row.
- A later tool result removes binder clones for that list only. It does not remove `[data-mcp-row]` elements the binder did not create. Do not set `data-mcp-reconnect`; the runtime does not read it.
- The runtime writes text with `textContent`, input values with the shared field writer, and attributes with `setAttribute` after the allowlist. It does not assign `innerHTML`. `$index` in a `data-mcp-attr-*` value is the zero-based clone index. `javascript:` URLs, `on*` attributes, `data-controller`, `data-action`, and names ending in `-target` are not written.
- Stimulus sees inserted nodes, so actions on those nodes work. A controller that binds targets only inside `connect` picks up a batch of new clones because its token is removed and restored. It is left alone when any of those rows is reused, including when a new row is added beside a kept row. FlatPack table sortable needs `rowTargetConnected` before that new row can listen. Refreshing the controller would stack listeners, because `removeDragListeners` does not remove the bound functions.
- `window.McpFields` is the shared field helper. Keep `controllers/editor_controller.js` ahead of `boot.js` in the packaged runtime.

## [0.3.0] - 2026-10-12

### Added
- `configuration.widget_script_path` inlines one host-built JavaScript file before the editor runtime. `nil`, or a missing file, leaves it out. The gem does not parse or rewrite that file.
- The editor collects repeated and nested `[data-mcp-field]` names (`sections[][title]`, `tags[]`, `user[name]`) into arrays and objects in DOM order, and reads `data-mcp-type` of `json`, `array`, or `object`.

### Changed
- Unchecked radios are omitted from the save payload. A checked radio still sends its value. Checkboxes stay booleans, including inside nested names.
- Field names `__proto__`, `constructor`, and `prototype` are ignored. Nested objects are built without a prototype, so a save payload cannot set `Object.prototype`.
- Repeatable rows are elements with `data-mcp-row`. `data-mcp-restore-order` on the editor puts those rows back in connect order when widget data is applied, then binds by position.
- A configured `widget_script_path` that is missing logs a warning. The file contents are still copied verbatim, with `</script` and `<!--` escaped so they cannot close the surrounding script.

### Upgrade notes
- Build Stimulus and the controllers you want with esbuild (see the README). Set `config.widget_script_path` to that file, for example `app/assets/builds/mcp_ui_widgets.js`. Leave it unset to keep the 0.2.0 script.
- Mark each repeatable row with `data-mcp-row`. Add `data-mcp-restore-order` on the editor when a data refresh should restore the connect order before binding. `tr` and `li` are not rows.
- TipTap, charts, remote search, and any `fetch()` inside a controller still cannot run: `connect-src` is `none`. Do not point `orderable_url` or `reorder_url` at the widget. Capture reorder in the DOM and send it on Save with `sections[][field]` names. Do not put those controllers in the bundle unless their imports are on disk.
- `sections[id][heading]` stays a hash keyed by id. Use empty brackets (`sections[][heading]`) when Save should receive an array in DOM order. Mark each value you want saved with `data-mcp-field`; unmarked hidden inputs are ignored.
- A name that previously relied on the last radio input winning, even when unchecked, now sends only the checked radio.

## [0.2.0] - 2026-10-12

### Added
- Widget CSS custom properties (`--mcp-ui-background`, `--mcp-ui-surface`, `--mcp-ui-surface-color`, and related tokens) so hosts can theme packaged documents without forking the gem.
- `configuration.compiled_css_path` accepts one local path or an array of local paths. Files are inlined in order after the gem (and Flatpack) CSS.

### Changed
- Packaged widget page (`html` / `body`) background defaults to transparent. A bare widget paints a light card (`--mcp-ui-surface: #fff`, `--mcp-ui-surface-color: #1f1f1f`). `#mcp-ui-root` is transparent only when a Flatpack card is its only child. Nested `.mcp-ui-card` / `.mcp-ui-form` inside that card stay transparent. Widget CSS paints Flatpack card classes from `--card-background-color` without host Tailwind.
- Widget documents declare `color-scheme: light dark` on `:root[data-theme]`. The page is transparent only when the OS/browser color preference matches the host's color scheme; otherwise the browser paints a solid canvas. Following the host theme is not implemented.
- Dummy project editor uses FlatPack Select for Status and FlatPack Buttons for Save (primary) and Cancel (secondary), still wired through `projects.update`.
- Dummy project editor form uses Tailwind `p-6` so the packaged widget has inset around the fields.
- Installer comments and README document host CSS overrides.

### Upgrade notes
- Widgets no longer paint an off-white page (`#f8f8f5`). The page is transparent; the card stays white with dark text. Override `--mcp-ui-surface` and `--mcp-ui-surface-color` in a local stylesheet and point `compiled_css_path` at it.
- `compiled_css_path` still accepts a single path. Pass an array when you already inline compiled CSS and need a second file that wins.

## [0.1.0] - 2026-10-09

### Added
- RecordingStudio MCP UI engine with in-memory widget registration (`register` / `find` / `list`).
- ViewComponent rendering and MCP Apps HTML packaging (`text/html;profile=mcp-app`).
- Shared JavaScript runtime (`mcpUI.execute`, dirty/loading/error state) on the official MCP Apps View SDK.
- Dummy Project preview and editor demos that persist through the registered `projects.update` tool.
- Integration spec for the RecordingStudio API and MCP changes this gem cannot ship.

### Changed
- Packaged documents vendor `@modelcontextprotocol/ext-apps` 2.0.3 (`App`, `PostMessageTransport`) instead of a custom JSON-RPC host.
- Packaged widget config includes the alias-to-tool-name map. `mcpUI.execute` calls `app.callServerTool` with the real tool name.
- `mcpUI.execute` rejects MCP tool results with `isError: true`.
- Dummy mounts API, Oauth, MCP, and Users so project widgets can be tried from an MCP Apps client over a tunnel.
- `mcpUI.execute` talks only to a connected View SDK host. Dummy and JS tests mock that host over `postMessage`.
- The runtime registers `ontoolresult` before `connect()` and applies `structuredContent` from the host tool-result notification.
- Boot binds every `[data-mcp-text]` node from `mcpUI.data()` after start and on each `onData`.
- `ontoolresult` and `execute` share one unwrap: `structuredContent`, then `data`. Dummy writes use `contextUpdate`.
- Editor fields re-bind only when widget data changes (`applyData` / `reset` / tool result). `markDirty` does not overwrite typed values.
- `Configuration#to_h` uses `RecordingStudio::Hooks#registered_counts`.
- Dummy pins `recording_studio_api` v0.6.11 and `recording_studio_mcp` v0.11.0.

### Removed
- Ruby `action_executor`, `visibility_checker`, and `RecordingStudio::MCP_UI.execute`. Widget writes are ordinary MCP tool calls.

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.1.1...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/releases/tag/v0.1.0
