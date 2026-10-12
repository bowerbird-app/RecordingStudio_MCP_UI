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
gem "recording_studio_mcp_ui", github: "bowerbird-app/RecordingStudio_MCP_UI", tag: "v0.4.0"
```

```bash
bundle install
bin/rails generate recording_studio_mcp_ui:install
```

The engine keeps Recording Studio conventions: `RecordingStudio::Hooks`, default layout in host apps, and strict recordable declarations. Pins: dummy GitHub tag `v4.5.0`, dummy GitHub tag `v0.15.0`, dummy GitHub tag `v0.8.0`, dummy GitHub tag `v0.1.213`.

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
2. Render fields with `data-mcp-field` and a `data-mcp-save="save"` button inside `data-controller="mcp-editor"`. Give repeated rows Rails-style names such as `sections[][title]` so Save sends an array in DOM order.
3. Call `await mcpUI.execute("save", payload)` from widget JS. The runtime maps `save` to the registered tool name and calls `app.callServerTool({ name, arguments })`.

The packaged document carries that alias-to-tool-name map. MCP treats the call as an ordinary tool invocation and applies the server's normal authorization.

## JavaScript API

Packaged documents define `window.mcpUI`:

- `mcpUI.start()`
- `mcpUI.data()` / `mcpUI.applyData(data)` / `mcpUI.reset()` — reset restores the first non-blank record. That is the packaged `data` when `resources/read` sent some, or the first tool result when the package was empty.
- `mcpUI.markDirty()` / `mcpUI.isDirty()`
- `mcpUI.onData(listener)` — listener receives `(data, { dirty, dataChanged, reset })`. `dataChanged` is true for `applyData`, `reset`, start, and accepted tool results. `reset` is true only for `mcpUI.reset()`. `markDirty` only flips `dirty`.
- `mcpUI.execute(alias, payload)` — looks up the real tool name and calls `app.callServerTool`; rejects unknown aliases without sending; rejects with `No action transport` when no host is connected

Host communication uses the official MCP Apps View SDK (`App` + `PostMessageTransport` from `@modelcontextprotocol/ext-apps`). The packaged document vendors that SDK, registers `ontoolresult` before `app.connect()`, and calls `app.callServerTool()` / `app.updateModelContext()`. The tool-result notification that opened the widget, and the result of `mcpUI.execute`, share one unwrap: use `structuredContent` when present, then `data` when that object has a `data` object. That is the widget record. A successful write may also include `contextUpdate` (camelCase) for `app.updateModelContext`. Boot writes widget data into every `[data-mcp-text]` node after start and on each `onData`, skipping nodes inside a rendered list row. The editor writes `[data-mcp-field]` values only when `dataChanged` is true, so typing then blurring Save does not restore the opening record. `execute` fills blank `id` and `revision` from current widget data so hidden fields that have not bound yet do not wipe the record. There is no per-client protocol, sniffing, or host-specific metadata. Clients that cannot load the UI keep the structured tool result.

### Lists

`resources/read` packages the widget with empty data. A Ruby loop has already taken the empty branch by the time `ui/notifications/tool-result` arrives. Repeating content, including editable rows, is a template the runtime clones. Put `data-mcp-row` and `data-mcp-field` on that template when Save should collect the row. The editor keeps each input's `name`, so `links[][label]` still becomes an array in DOM order.

```html
<div data-mcp-list="topics">
  <template data-mcp-list-item>
    <span data-mcp-text></span>
  </template>
  <p data-mcp-list-empty>No topics yet.</p>
</div>

<tbody data-mcp-list="links">
  <template data-mcp-list-item>
    <tr data-mcp-row data-mcp-attr-data-id="id">
      <td><input name="links[][label]" data-mcp-field></td>
    </tr>
  </template>
  <tr data-mcp-list-empty><td>No data available</td></tr>
</tbody>
```

| Attribute | Where | Meaning |
| --- | --- | --- |
| `data-mcp-list` | container | Key on the widget record whose value is the array |
| `data-mcp-list-item` | `<template>` | One item. Cloned for each plain object. A string, number, or boolean is cloned only when the template's text slot is empty |
| `data-mcp-list-empty` | element | Shown when the array is missing or empty. Hidden when it has entries |
| `data-mcp-text` | inside the item | Field name on an object. Leave it empty for a scalar such as a topic string |
| `data-mcp-field` | input inside the item | Value is set from the item. The name stays. `links[][label]` reads the item's `label`. A missing key keeps the template value |
| `data-mcp-row` | row inside the item | Opts the clone into save order. The binder does not remove a row it did not clone |
| `data-mcp-attr-<name>` | element inside the item | Sets one allowlisted attribute. The value is a field name, or a string containing `$index` (`note-$index-content`) |

Null, arrays, and other values that are not plain objects are skipped, so they do not become blank rows. A string, number, or boolean still clones when the template has an empty `data-mcp-text` and no named text field, which is how a topic chip renders. `$index` counts only the items that were cloned.

A tool result removes only `[data-mcp-list-entry]` clones that belong to that list. A row a collection editor added stays. The empty element it toggles is the one whose list is that container, so a nested list keeps its own empty state. An item with an `id` reuses the clone from the previous result: text slots and allowlisted attributes refresh, and the inputs keep what the person typed. Items with no `id` are cloned again. `mcpUI.reset()` writes the opening record back into a reused row. `data-mcp-list-entry` and `data-mcp-list-key` are runtime markers; do not author them.

`data-mcp-attr-*` may set `id`, `class`, `title`, `value`, `data-*`, and `aria-*`. `href` and `src` are set only for `http:`, `https:`, `mailto:`, or a relative URL. Names starting with `on`, plus `style`, `srcdoc`, `data-controller`, `data-action`, any name ending in `-target`, and every other name, are left unset. The check is case-insensitive. `javascript:` is not written. The runtime uses `textContent`, the input `value` property, and `setAttribute`. It does not use `innerHTML`.

Boot builds the list before the editor rebinds fields outside the list. The editor does not write inputs inside a list clone; the binder does. `markDirty` does not rebuild the list. When every row in a result is a new clone, and a clone carries `data-<identifier>-target`, the runtime removes that identifier from `data-controller` on the list or an ancestor and puts the original token list back on the next microtask. Stimulus disconnects and connects that controller, so it binds the new rows. A result that reuses a row leaves `data-controller` alone. A new row beside a reused row is not bound by that refresh. FlatPack's table sortable attaches drag listeners in `connect` with bound functions, and `removeDragListeners` only clears `draggable`, so a second connect would stack listeners on the rows that were kept. Binding one new target belongs on that controller as `rowTargetConnected`. There is no `data-mcp-reconnect` attribute. `data-mcp-restore-order` still puts other repeatable rows back in connect order. List clones stay in the order the binder just placed.

## How Flatpack CSS and Stimulus get into widget HTML

`RecordingStudio::MCP_UI::Packager` inlines:

1. `app/assets/stylesheets/recording_studio_mcp_ui/widget.css`
2. FlatPack `variables.css` and `application.css` from `FlatPack::Engine` when that gem is installed
3. Optional host CSS from `configuration.compiled_css_path` — one local path or an array of local paths, in order (dummy uses Tailwind then `app/assets/stylesheets/mcp_ui_widget.css`)
4. The official SDK IIFE (`vendor/ext-apps.iife.js`)
5. The host's prebuilt widget script from `configuration.widget_script_path`, when that file exists
6. `runtime.js`, then `controllers/editor_controller.js`, then `boot.js`

`editor_controller.js` assigns `window.McpFields` with `own`, `inputType`, `writeField`, and `inputFieldKey`. `boot.js` reads that object for list text, list fields, and the own-property check. The packaged runtime concatenates the files in that order. If `window.McpFields` is missing, or is missing one of those functions, `boot.js` logs one error and still calls `mcpUI.start()`. List and field binding does nothing until the editor file has run.

Host CSS and the widget script are read from disk at package time. A missing CSS path is skipped. A configured `widget_script_path` that is not a file logs a warning and is skipped. `nil` leaves the script out and stays quiet. Do not pass URLs; CSP allows only inline style and script.

The document is a self-contained HTML page. It does not fetch host importmaps or layout assets at view time. The editor controller is Stimulus-shaped (`data-controller="mcp-editor"`) and talks only through `mcpUI`.

### Stimulus in the widget

The gem does not bundle Stimulus. The host builds one classic script with esbuild (or another bundler) and points `widget_script_path` at it. `nil` leaves Stimulus out of the widget. The file is copied in before the editor runtime.

```javascript
// app/javascript/mcp_ui_widgets.js
import { Application } from "@hotwired/stimulus"
import TabsController from "flat_pack/controllers/tabs_controller"
import CollectionEditorController from "flat_pack/controllers/collection_editor_controller"

const application = Application.start()
application.register("flat-pack--tabs", TabsController)
application.register("flat-pack--collection-editor", CollectionEditorController)
window.Stimulus = application
```

```javascript
// esbuild.config.mjs
import * as esbuild from "esbuild"
import { execSync } from "node:child_process"
import path from "node:path"

const flatPack = execSync("bundle info --path flat_pack", { encoding: "utf8" }).trim()
const javascript = path.join(flatPack, "app/javascript/flat_pack")

await esbuild.build({
  entryPoints: ["app/javascript/mcp_ui_widgets.js"],
  bundle: true,
  format: "iife",
  platform: "browser",
  outfile: "app/assets/builds/mcp_ui_widgets.js",
  nodePaths: [path.resolve("node_modules")],
  alias: {
    flat_pack: javascript,
    "controllers/flat_pack": path.join(javascript, "controllers")
  }
})
```

`flat_pack/controllers/...` and `controllers/flat_pack/...` are the specifiers FlatPack controllers already use. The alias points them at the installed gem. Install `@hotwired/stimulus` and `esbuild` in the host, then run `node esbuild.config.mjs`.

```ruby
config.widget_script_path = Rails.root.join("app/assets/builds/mcp_ui_widgets.js")
```

Include only controllers whose imports esbuild can bundle from disk. TipTap (`@tiptap/core`), ApexCharts, the Google Charts loader, remote search, and any controller `fetch()` still cannot run: the sandbox CSP has `connect-src 'none'`. Drag-reorder that only changes the DOM still runs. A PATCH to `orderable_url` or `reorder_url` does not. Send the new order on Save.

### Structured save fields

Save reads `[data-mcp-field]` elements only.

- A plain name (`title`, or `data-mcp-field` without brackets) stays a string. Checkboxes are booleans. Unchecked radios are omitted.
- Bracket names follow form semantics, in DOM order: `sections[][title]` becomes an array of objects, `tags[]` becomes an array, and `user[name]` becomes an object. A new object starts when the same child key appears again on the last array element, so a drag that moves the row moves that object.
- `data-mcp-type="json"`, `"array"`, or `"object"` JSON-parses the value. Empty input becomes `null`, `[]`, or `{}`. A parse failure keeps the raw string.
- Disabled fields, file inputs, and buttons are skipped.

Hidden FlatPack inputs such as `id` and `_destroy` are collected only when they also have `data-mcp-field`. Names `__proto__`, `constructor`, and `prototype` are ignored.

A repeatable row opts in with `data-mcp-row` on the element that should move as a unit. `tr` and `li` are ordinary markup. Put `data-mcp-restore-order` on the editor (`data-controller="mcp-editor"`) when a data refresh should move those rows back to the order from connect, then write values by that position. Without the attribute, rows stay where they are and values bind in the current DOM order.

### Widget CSS tokens

The packaged page (`html` / `body`) is transparent so the host shows through. A bare widget paints `--mcp-ui-surface` on `#mcp-ui-root` and on `.mcp-ui-card` / `.mcp-ui-form`. `#mcp-ui-root` is transparent only when a Flatpack card (`--card-background-color`) is its only child, so headers and actions beside a card stay on the light surface. Nested `.mcp-ui-card` / `.mcp-ui-form` inside that card are transparent so the card colour shows through. Widget CSS paints those Flatpack card classes from `--card-background-color` even when the host has not inlined Tailwind. Inputs keep a readable `--mcp-ui-surface` fill. A component that sets its own background still wins on that element.

The page is transparent only when the OS/browser color preference matches the host's color scheme; otherwise the browser paints a solid canvas (white on a dark host, black on a light host). Following the host theme is not implemented. Hosts that override `color-scheme` must target `:root[data-theme]` (the packager sets `data-theme` on `html`).

Override tokens (or any widget rule) in the host stylesheet:

```css
:root {
  --mcp-ui-background: transparent; /* page, default */
  --mcp-ui-surface: #fff;           /* card, default */
  --mcp-ui-surface-color: #1f1f1f;  /* card text, default */
  --mcp-ui-surface-scheme: light;   /* native controls on the card */
  --mcp-ui-padding: 1rem;
  --mcp-ui-font-family: ui-sans-serif, system-ui, sans-serif;
}
```

```ruby
RecordingStudio::MCP_UI.configure do |config|
  config.compiled_css_path = Rails.root.join("app/assets/stylesheets/mcp_ui_widget.css")
  config.widget_script_path = Rails.root.join("app/assets/builds/mcp_ui_widgets.js")
end
```

Later files win. To keep a compiled app stylesheet and still tweak the widget, pass both:

```ruby
config.compiled_css_path = [
  Rails.root.join("app/assets/builds/tailwind.css"),
  Rails.root.join("app/assets/stylesheets/mcp_ui_widget.css")
]
```

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
- Demo B: `/demos/:id/edit` — editor that POSTs to `Demo::ProjectUpdate`. The widget is a FlatPack card (page title in the header, fields in the body). Title, description, Status, Save, and Cancel are FlatPack components. Error and status lines are FlatPack alerts. Dummy Tailwind in `compiled_css_path` styles them in the packaged document.
- Packaged document: `/demos/:id/document?widget=projects.preview`
- Page demo: `/page_demos/:id` — FlatPack collection editor, sortable links table, tabs, topic chips, and accordion for a Page recording. Section heading and body are text inputs with `chrome: :cell`. The links table is a draggable FlatPack table (one reorder grip per row). The visible label is FlatPack Content and the URL is a FlatPack link, with `links[]` fields on each row. Section and link fields use `sections[]` and `links[]` names with `data-mcp-field`, so Save sends those arrays in DOM order through `pages.update` and revises the page. Drag reorder does not set `orderable_url` or `reorder_url`. Header sort on the links table reloads the document. Packaged HTML: `/page_demos/:id/document?widget=pages.sections` (also `pages.links`, `pages.tabs`, `pages.topics`, `pages.notes`). The dummy esbuild entry registers the collection editor, list orderable, table sortable, tabs, chip, and accordion controllers, and `widget_script_path` points at `app/assets/builds/mcp_ui_widgets.js`.

The demo save path is a test stand-in. It never reports a successful save unless the Project row was updated.

## Testing

```bash
bundle exec rake test
bundle exec rake test:dummy
node --test test/javascript/*_test.js
```

## Required external work

Documented in [docs/api_mcp_integration.md](docs/api_mcp_integration.md): `ui:` on API registrations, MCP `resources/list` and `resources/read` for `ui://`, and ordinary tool authorization for widget calls.
