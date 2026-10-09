# Vendored official MCP Apps SDK

This directory contains the official `@modelcontextprotocol/ext-apps` View SDK
(`App`, `PostMessageTransport`) bundled as an IIFE from the published
`app-with-deps` entry. Version: **2.0.3**.

It is not a host-specific adapter. Rebuild:

```bash
npm install --prefix /tmp/mcp-apps-sdk @modelcontextprotocol/ext-apps@2.0.3 esbuild
# wrap.mjs: export { App, PostMessageTransport } from "@modelcontextprotocol/ext-apps/app-with-deps"
npx --prefix /tmp/mcp-apps-sdk esbuild wrap.mjs --bundle --format=iife --global-name=McpApps --outfile=ext-apps.iife.js
```

License: see `LICENSE.ext-apps` (Apache-2.0 / MIT as published by the MCP project).
