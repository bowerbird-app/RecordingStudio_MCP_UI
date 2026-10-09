# RecordingStudio API and MCP integration spec

This gem does not modify RecordingStudio API or RecordingStudio MCP. Those gems need the following additions so MCP Apps can discover widgets.

## Ownership

- MCP UI owns widget definitions, rendering, and HTML packaging.
- RecordingStudio API owns operations, schemas, access grants, and versioning.
- RecordingStudio MCP owns MCP transport, tool exposure, and `resources/read`.

Do not auto-create an MCP tool because a widget was registered. An API operation must associate itself with a widget identifier.

## RecordingStudio API additions

Keep `RecordingStudioApi.register_endpoint` / `register_capability_action` / `register_recordable_type_api` as the only action registries.

### 1. Optional `ui:` on existing registrations

```ruby
RecordingStudioApi.register_endpoint(
  "presskits.edit",
  http_verb: :patch,
  path: "presskits/:id",
  handler: Presskits::Edit,
  ui: "presskits.editor"
)

RecordingStudioApi.register_capability_action(
  :update_presskit,
  capability: :presskits,
  handler: Presskits::Update,
  ui: "presskits.editor"
)
```

Store `ui` on the existing endpoint/action object as a string widget id. Do not store widget HTML or component classes in the API gem.

### 2. Lookup helpers

```ruby
RecordingStudioApi.ui_for(action_name, api: :public, version: nil)
# => "presskits.editor" or nil

RecordingStudioApi.actions_for_ui("presskits.editor", api: :public, version: nil)
# => registered action objects whose metadata.ui matches
```

Honor named API surfaces and version profiles the same way capability lookup already does.

### 3. Contribution contract

Third-party gems continue to register API operations in their own engines. They additionally pass `ui:`. MCP UI registration stays in the third-party engine:

```ruby
RecordingStudio::MCP_UI.register(
  "presskits.editor",
  component: Presskits::EditorComponent,
  mode: :edit,
  actions: { save: "presskits.update" }
)
```

The API string (`presskits.update`) is the MCP tool name the widget runtime sends to `app.callServerTool`.

## RecordingStudio MCP additions

### 1. Discover UI from API metadata

When building a tool from an API operation, if `RecordingStudioApi.ui_for(action)` is present and `RecordingStudio::MCP_UI.find(id)` succeeds, add MCP Apps tool metadata:

```json
{
  "_meta": {
    "ui": {
      "resourceUri": "ui://presskits/editor"
    }
  }
}
```

Do not invent a second association table.

### 2. Serve UI resources

Implement `resources/list` and `resources/read` for `ui://` URIs. Read by calling:

```ruby
document = RecordingStudio::MCP_UI.package(widget_id, data: structured_tool_result)
document.to_mcp_resource
```

MCP obtains the HTML from MCP UI in-process. Do not HTTP-proxy through RecordingStudio API to fetch the widget.

MIME type: `text/html;profile=mcp-app`.

The packaged document already includes the widget's alias-to-tool-name map. Widget JS calls `mcpUI.execute("save", payload)`. The runtime looks up `save` and calls `app.callServerTool({ name: "presskits.update", arguments })`. That is an ordinary MCP `tools/call`. The server's normal tool authorization applies. MCP does not resolve action aliases and does not wire `action_executor` or `visibility_checker`.

A tool result that opens or updates a widget uses this shape in `structuredContent`:

- Record fields at the top level (`id`, `title`, …), or
- `{ "ok": true, "data": { …record fields }, "contextUpdate": "…" }`

The view unwraps `data` when present and treats `contextUpdate` as the optional model-context string (camelCase, not `context_update`). Editor fields re-bind from that record only when data changes, not when the form is marked dirty.

### 3. Visibility

```ruby
RecordingStudio::MCP_UI.available?(
  widget_id,
  access_grant: grant,
  api: :public,
  version: "v1"
)
```

`available?` honors the widget's `available_if` hook. A registered widget is not globally visible. Displaying a field is not write permission. Writes go through the mapped tool and the server's existing access grant, named API, version, and Accessible checks.

### 4. Clients without MCP Apps

Keep structured tool results. If the client cannot load `ui://` resources, return the existing text/structured result. Do not fail the tool because UI packaging is unavailable.

### 5. Official MCP Apps SDK

Hosts and views use the official MCP Apps SDK (`@modelcontextprotocol/ext-apps`). This gem vendors the published View SDK and uses `App.connect` / `App.callServerTool` / `App.updateModelContext` only. Do not add client sniffing, per-host branches, host-specific `_meta` keys, or protocol workarounds. If a client cannot render `text/html;profile=mcp-app`, return the structured tool result.

## Circular dependencies

- MCP UI must not require `recording_studio_api` or `recording_studio_mcp`.
- API stores a string widget id only.
- MCP depends on both API and MCP UI.

## Dummy stand-in

`POST /demos/:id/save` exists only in `test/dummy`. It calls `Demo::ProjectUpdate`, the same persistence path a conventional request would use. It is not a second API registry.
