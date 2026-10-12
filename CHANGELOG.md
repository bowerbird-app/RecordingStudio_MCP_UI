# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-10-12

### Added
- Widget CSS custom properties (`--mcp-ui-background`, `--mcp-ui-surface`, `--mcp-ui-surface-color`, and related tokens) so hosts can theme packaged documents without forking the gem.
- `configuration.compiled_css_path` accepts one local path or an array of local paths. Files are inlined in order after the gem (and Flatpack) CSS.

### Changed
- Packaged widget page (`html` / `body`) background defaults to transparent. A bare widget paints a light card (`--mcp-ui-surface: #fff`, `--mcp-ui-surface-color: #1f1f1f`). `#mcp-ui-root` is transparent only when a Flatpack card is its only child. Nested `.mcp-ui-card` / `.mcp-ui-form` inside that card stay transparent. Widget CSS paints Flatpack card classes from `--card-background-color` without host Tailwind.
- Widget documents declare `color-scheme: light dark` on `:root[data-theme]`. The page is transparent only when the OS/browser color preference matches the host's color scheme; otherwise the browser paints a solid canvas. Following the host theme is not implemented.
- Dummy project editor uses FlatPack Select for Status and FlatPack Buttons for Save (primary) and Cancel (secondary), still wired through `projects.update`.
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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.1.1...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/releases/tag/v0.1.0
