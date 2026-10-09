# Dummy App

This Rails app exists to validate RecordingStudio MCP UI in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Recording Studio default layout, FlatPack assets, and Tailwind source scanning
- Two MCP UI demos: a Project preview card and a Project editor
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
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/up` - Rails health check
- `/recording_studio_mcp` - Streamable HTTP MCP endpoint
- `/recording_studio_oauth` - Oauth Connect
- `/recording_studio_api` - same actions as MCP, over HTTP
- `/.well-known/oauth-protected-resource/recording_studio_mcp` - MCP protected-resource metadata
