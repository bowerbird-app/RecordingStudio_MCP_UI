# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Packaged documents vendor `@modelcontextprotocol/ext-apps` 2.0.3 (`App`, `PostMessageTransport`) instead of a custom JSON-RPC host.
- Packaged widget config includes the alias-to-tool-name map. `mcpUI.execute` calls `app.callServerTool` with the real tool name.
- `mcpUI.execute` rejects MCP tool results with `isError: true`.
- Dummy mounts API, Oauth, MCP, and Users so project widgets can be tried from an MCP Apps client over a tunnel.
- `mcpUI.execute` talks only to a connected View SDK host. Dummy and JS tests mock that host over `postMessage`.
- The runtime registers `ontoolresult` before `connect()` and applies `structuredContent` from the host tool-result notification.
- Boot binds every `[data-mcp-text]` node from `mcpUI.data()` after start and on each `onData`.
- `Configuration#to_h` uses `RecordingStudio::Hooks#registered_counts`.

### Removed
- Ruby `action_executor`, `visibility_checker`, and `RecordingStudio::MCP_UI.execute`. Widget writes are ordinary MCP tool calls.

## [0.1.0] - 2026-10-09

### Added
- RecordingStudio MCP UI engine with in-memory widget registration (`register` / `find` / `list`).
- ViewComponent rendering and MCP Apps HTML packaging (`text/html;profile=mcp-app`).
- Shared JavaScript runtime (`mcpUI.execute`, dirty/loading/error state) on the official MCP Apps View SDK.
- Dummy Project preview and editor demos that persist through the registered `projects.update` tool.
- Integration spec for the RecordingStudio API and MCP changes this gem cannot ship.

This repository has no prior git tags or GitHub releases. `0.1.0` is the first version of this gem.

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_MCP_UI/releases/tag/v0.1.0
