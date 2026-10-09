# RecordingStudio MCP UI

Reusable Rails engine that lets Recording Studio gems register interactive MCP Apps widgets. MCP UI owns the interface. RecordingStudio API owns the actions. RecordingStudio MCP exposes those actions and their interfaces to AI clients.

This gem does not add a second CRUD system, API registry, authorization stack, or MCP server.

## Architecture

```
Third-party gem
  → RecordingStudio::MCP_UI.register(...)   # widget definition
  → RecordingStudioApi.register_* (... ui:) # action + widget id  (API gem, not this repo)

RecordingStudio MCP
  → finds the widget id on the API operation
  → RecordingStudio::MCP_UI.package(...)    # HTML resource, in-process
  → tools/call → existing API handler
```

See [docs/api_mcp_integration.md](docs/api_mcp_integration.md) for the exact API and MCP additions still required in those repositories.

## Installation

```ruby
gem "recording_studio_mcp_ui", github: "bowerbird-app/RecordingStudio_MCP_UI", tag: "v0.1.0"
```

```bash
bundle install
bin/rails generate recording_studio_mcp_ui:install
```

The engine keeps Recording Studio conventions: `RecordingStudio::Hooks`, default layout in host apps, and strict recordable declarations. Pins: dummy GitHub tag `v4.4.0`, dummy GitHub tag `v0.11.1`, dummy GitHub tag `v0.5.3`, dummy GitHub tag `v0.1.207`.

## Public Ruby API

```ruby
RecordingStudio::MCP_UI.register(
  "presskits.preview",
  component: Presskits::PreviewComponent,
  description: "Displays a press kit",
  mode: :read,
  version: "1.0.0"
)

RecordingStudio::MCP_UI.register(
  "presskits.editor",
  component: Presskits::EditorComponent,
  description: "Edit a press kit",
  mode: :edit,
  version: "1.0.0",
  actions: { save: "presskits.update" },
  available_if: ->(access_grant:, **) { access_grant.present? }
)

RecordingStudio::MCP_UI.find("presskits.editor")
RecordingStudio::MCP_UI.list(mode: :edit, prefix: "presskits.")
RecordingStudio::MCP_UI.render("presskits.preview", data: payload)
document = RecordingStudio::MCP_UI.package("presskits.preview", data: payload)
document.to_mcp_resource
RecordingStudio::MCP_UI.available?("presskits.editor", access_grant: grant, api: :public)
```

`register` / `find` / `list` never instantiate the component. The registry is in-memory. Duplicate ids fail unless the contract is identical (reload-safe). Lookup metadata never includes record data. Registering a widget does not grant API access.

## First read-only widget

1. Create a ViewComponent that accepts `data:`.
2. Register it from your engine's `to_prepare`.
3. Ask MCP (once integrated) for `RecordingStudio::MCP_UI.package("your.preview", data: authorized_payload)`.

```ruby
class Projects::PreviewComponent < ViewComponent::Base
  def initialize(data:)
    @data = data
  end
end
```

## First editable widget

1. Register `mode: :edit` and `actions: { save: "your.api_action" }`.
2. Render fields with `data-mcp-field` and a `data-mcp-save="save"` button inside `data-controller="mcp-editor"`.
3. Call `await mcpUI.execute("save", payload)` from widget JS. The runtime maps `save` to the registered tool name and calls `app.callServerTool({ name, arguments })`.

The packaged document carries that alias-to-tool-name map. MCP treats the call as an ordinary tool invocation and applies the server's normal authorization.

## JavaScript API

Packaged documents define `window.mcpUI`:

- `mcpUI.start()`
- `mcpUI.data()` / `mcpUI.applyData(data)` / `mcpUI.reset()`
- `mcpUI.markDirty()` / `mcpUI.isDirty()`
- `mcpUI.onData(listener)` — listener receives `(data, { dirty, dataChanged })`. `dataChanged` is true for `applyData`, `reset`, start, and accepted tool results. `markDirty` only flips `dirty`.
- `mcpUI.execute(alias, payload)` — looks up the real tool name and calls `app.callServerTool`; rejects unknown aliases without sending; rejects with `No action transport` when no host is connected

Host communication uses the official MCP Apps View SDK (`App` + `PostMessageTransport` from `@modelcontextprotocol/ext-apps`). The packaged document vendors that SDK, registers `ontoolresult` before `app.connect()`, and calls `app.callServerTool()` / `app.updateModelContext()`. The tool-result notification that opened the widget, and the result of `mcpUI.execute`, share one unwrap: use `structuredContent` when present, then `data` when that object has a `data` object. That is the widget record. A successful write may also include `contextUpdate` (camelCase) for `app.updateModelContext`. Boot writes widget data into every `[data-mcp-text]` node after start and on each `onData`. The editor writes `[data-mcp-field]` values only when `dataChanged` is true, so typing then blurring Save does not restore the opening record. `execute` fills blank `id` and `revision` from current widget data so hidden fields that have not bound yet do not wipe the record. There is no per-client protocol, sniffing, or host-specific metadata. Clients that cannot load the UI keep the structured tool result.

## How Flatpack CSS and Stimulus get into widget HTML

`RecordingStudio::MCP_UI::Packager` inlines:

1. `app/assets/stylesheets/recording_studio_mcp_ui/widget.css`
2. FlatPack `variables.css` and `application.css` from `FlatPack::Engine` when that gem is installed
3. Optional host compiled CSS from `configuration.compiled_css_path` (dummy uses `app/assets/builds/tailwind.css`)
4. The official SDK IIFE (`vendor/ext-apps.iife.js`) plus `runtime.js`, `controllers/editor_controller.js`, and `boot.js`

The document is a self-contained HTML page. It does not assume host importmaps or layout assets. The editor controller is Stimulus-shaped (`data-controller="mcp-editor"`) and talks only through `mcpUI`.

## Data, editing, and security

- One widget definition is reused for many records.
- Local form state is temporary. Recording Studio remains the source of truth.
- Validation and authorization failures return structured errors. Successful saves replace widget data.
- If the API supplies a revision, a stale save returns a conflict instead of overwriting.
- Packaged HTML strips keys matching token/secret/password/authorization/api_key/credential.
- CSP defaults to no network, no frames, inline script/style only.
- Treat tool-result data as untrusted; escape it in components.

## Dummy app

Sign in at `/users/sign_in` with `admin@admin.com` / `Password`.

- Demo A: `/demos/:id` — read-only Project card
- Demo B: `/demos/:id/edit` — editor that POSTs to `Demo::ProjectUpdate`
- Packaged document: `/demos/:id/document?widget=projects.preview`

The demo save path is a test stand-in. It never reports a successful save unless the Project row was updated.

## Testing

```bash
bundle exec rake test
bundle exec rake test:dummy
node --test test/javascript/*_test.js
```

## Required external work

Documented in [docs/api_mcp_integration.md](docs/api_mcp_integration.md): `ui:` on API registrations, MCP `resources/list` and `resources/read` for `ui://`, and ordinary tool authorization for widget calls.
