RecordingStudio MCP UI install complete.

Next steps:

1. Review config/initializers/recording_studio_mcp_ui.rb.
2. Register widgets from third-party engines with RecordingStudio::MCP_UI.register.
3. Install the engine migrations with `bin/rails generate recording_studio_mcp_ui:migrations` if this gem later ships tables.
4. Apply host migrations with `bin/rails db:migrate`.
5. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
6. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
7. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.
8. Do not create API actions or MCP tools from this gem. Associate UI identifiers from RecordingStudio API.
