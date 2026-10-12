# Dummy App

This Rails app exists to validate RecordingStudio MCP UI in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Recording Studio default layout, FlatPack assets, and Tailwind source scanning
- Two MCP UI demos: a Project preview card and a Project editor. The editor is a FlatPack card with the page title in the header and the fields in the body. Title is a FlatPack text input. Description is a FlatPack textarea. Status is FlatPack Select. Save and Cancel are FlatPack Buttons. Error and status lines are FlatPack alerts. The preview uses FlatPack Content and a Badge. Dummy Tailwind in `compiled_css_path` styles them in the packaged document. The editor has no repeatable rows. A host that adds them marks each row with `data-mcp-row` and, when reset should restore connect order, puts `data-mcp-restore-order` on the editor. Topic chips and the story outline are display lists (`data-mcp-list`): `resources/read` packages them empty, and the tool result fills the template. `npm run build:widgets` bundles Stimulus and selected FlatPack controllers with esbuild into `app/assets/builds/mcp_ui_widgets.js`, which packaged documents inline through `widget_script_path`.
- A Page demo (`Launch notes`) with FlatPack widgets packaged as `ui://` resources: collection editor for sections, sortable links table, tabs, topic chips, and an accordion. The page is a recordable. Section rows, including the add-row template, use `sections[][id]`, `sections[][heading]`, `sections[][body]`, and `sections[][_destroy]` with `data-mcp-field`. Heading and body are FlatPack text inputs with `chrome: :cell`, the same control the collection editor demo puts in a headed row. The links table follows the draggable table demo: one reorder grip per row. The visible label is FlatPack Content and the URL is a FlatPack link, with `links[][id]`, `links[][label]`, and `links[][url]` on the row so Save still collects them. Save sends those arrays in DOM order through `pages.update` and `revise`. Drag reorder does not set `orderable_url` or `reorder_url`. Header sort on the links table reloads the document. `app/javascript/mcp_ui_widgets.js` registers `flat-pack--collection-editor`, `flat-pack--list-orderable`, `flat-pack--table-sortable`, `flat-pack--tabs`, `flat-pack--chip`, and `flat-pack--accordion`.
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- Dummy-only `/docs/*` pages for gem-specific onboarding

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

Dev defaults (override with env):

- `DUMMY_ADMIN_EMAIL` — default `admin@admin.com`
- `DUMMY_ADMIN_PASSWORD` — default `Password`

## MCP over a tunnel

The dummy mounts API, Oauth, MCP, Users, and the well-known discovery routes. Widget buttons call the real tool names (`projects.show`, `projects.update`).

```bash
cd test/dummy
bundle install
bin/rails db:prepare
bin/rails db:seed
DUMMY_ALLOWED_HOST=your-subdomain.ngrok-free.app \
DUMMY_ALLOWED_ORIGINS=https://your-mcp-apps-client.example \
bin/rails server -b 0.0.0.0 -p 3000
```

In another terminal:

```bash
ngrok http 3000
```

Add the public MCP URL in any MCP Apps client (connector or Developer Mode):

```
https://your-subdomain.ngrok-free.app/recording_studio_mcp
```

Set `DUMMY_ALLOWED_HOST` to the ngrok hostname (no scheme). Set `DUMMY_ALLOWED_ORIGINS` to a comma-separated list of browser origins that may call MCP. Do not commit those values.

Sign in at `/users/sign_in`, then Connect **Seed MCP App** in Oauth so the client has an Accessible grant.

## Useful Routes

- `/` - dummy app home page and MCP UI demo links
- `/demos/:id` - read-only project card
- `/demos/:id/edit` - project editor
- `/page_demos/:id` - page component gallery (sections editor, links, tabs, topics, notes)
- `/page_demos/:id/document?widget=pages.sections` - packaged MCP Apps HTML for a page widget (`pages.links`, `pages.tabs`, `pages.topics`, `pages.notes`)
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/up` - Rails health check
- `/recording_studio_mcp` - Streamable HTTP MCP endpoint
- `/recording_studio_oauth` - Oauth Connect
- `/recording_studio_api` - same actions as MCP, over HTTP
- `/.well-known/oauth-protected-resource/recording_studio_mcp` - MCP protected-resource metadata
