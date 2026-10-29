# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.2] - 2026-10-28

### Changed
- Audit cleanup: untrack SimpleCov output, drop nested dummy GitHub config, leftover template docs, Copilot agent files, and the dummy docs-methods page. Refresh kit pin docs from the current gemspec and Gemfiles. Set `.ruby-version` to `3.3` so Security CI can install Ruby. `bin/rename_gem` is unchanged.
- Dummy FlatPack GitHub pin `v0.1.213` → `v0.1.329` so Bundler Audit can resolve `view_component` `>= 4.14`.

### Upgrade notes
- No library or public API change. Hosts do not need to change application code.

## [0.4.1] - 2026-10-14

### Changed
- Dependency-only bump (tag `v0.4.1`; no prior CHANGELOG entry). Root `recording_studio` GitHub tag `v4.5.0` → `v4.6.0`. Dummy GitHub tags: Recording Studio `v4.5.0` → `v4.6.0`, Accessible `v0.15.0` → `v0.17.0`, Admin `v2.1.0` → `v2.3.0`, API `v0.6.11` → `v0.7.0`, MCP `v0.11.0` → `v0.13.1`, Oauth `v0.7.0` → `v0.10.1`, Users `v0.17.0` → `v0.21.0`, Metrics `v0.2.0` → `v0.2.3`, Site Settings `v0.1.3` → `v0.2.0`, Root Switchable `v0.8.0` → `v0.9.0`. Added dummy pins for Trashable `v0.10.0` and Cache `v0.5.0`. Dummy admin resolver uses `recording_studio_trashable_kept_sql` instead of `trashed_at: nil`.

### Upgrade notes
- No MCP UI library or public API change. Refresh host kit pins if you track this gem's dummy/root Gemfiles.

## [0.4.0] - 2026-10-13

### Added
- English locale keys under `recording_studio.mcp_ui.editor.*` for editor status copy (`Saving…`, `Saved`, `Save failed`) in `config/locales/en.yml`.
- Packaged `#mcp-ui-config` includes an `i18n.editor` blob so the editor controller can show host-overridden status strings. JS keeps the previous English literals as fallbacks when the blob is absent.
- Hosts override editor status copy by defining the same keys in their own `config/locales`.

### Changed
- Editor status (`Saving…` / `Saved` / `Save failed`) resolves through I18n at package time and is read from the packaged `i18n` blob at render. English output stays byte-identical to 0.3.0.
- Runtime `Error` messages (`Tool call failed`, `Unknown action alias: …`, `No action transport`) stay main’s English literals; they are public API for host widget code.

### Upgrade notes
- No code changes required for English hosts. To translate editor status strings, add matching `recording_studio.mcp_ui.editor.*` keys in the host locale files. Packaged documents pick up the active locale when `RecordingStudio::MCP_UI.package` runs.
- Do not translate runtime `execute` / tool-error `Error` messages via locale keys; keep those English literals.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.4.2...HEAD
[0.4.2]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.1.1...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/releases/tag/v0.1.0
