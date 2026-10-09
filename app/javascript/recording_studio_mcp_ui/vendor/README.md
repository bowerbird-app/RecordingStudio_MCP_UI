# Vendored official MCP Apps SDK

`ext-apps.iife.js` is `@modelcontextprotocol/ext-apps` **2.0.3** `app-with-deps`,
bundled without source edits so a classic `<script>` can expose `App` and
`PostMessageTransport` as `window.McpApps`.

Regenerate (do not hand-edit the IIFE):

```bash
npm run vendor:ext-apps
```

That runs `script/vendor_ext_apps.mjs`, which installs
`@modelcontextprotocol/ext-apps@2.0.3` and `esbuild@0.25.12` in a temp
directory and writes this file.

License: `LICENSE.ext-apps` as published by the MCP project.
