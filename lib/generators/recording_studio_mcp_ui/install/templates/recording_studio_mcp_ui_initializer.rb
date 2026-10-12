# frozen_string_literal: true

RecordingStudio::MCP_UI.configure do |config|
  # Local CSS file(s) inlined after the gem's widget.css (and Flatpack CSS, when
  # Flatpack is installed). Later files win. Missing paths are skipped. Never a URL.
  #
  # Widget tokens (override in host CSS):
  #   --mcp-ui-background      (page, default: transparent)
  #   --mcp-ui-surface         (card, default: #fff)
  #   --mcp-ui-surface-color   (card text, default: #1f1f1f)
  #   --mcp-ui-surface-scheme  (native controls, default: light)
  #
  # config.compiled_css_path = Rails.root.join("app/assets/stylesheets/mcp_ui_widget.css")
  # config.compiled_css_path = [
  #   Rails.root.join("app/assets/builds/tailwind.css"),
  #   Rails.root.join("app/assets/stylesheets/mcp_ui_widget.css")
  # ]
  #
  # Prebuilt widget script, inlined before the editor runtime. Build it with
  # esbuild (Stimulus + the controllers this host wants). nil leaves Stimulus out.
  # A missing file logs a warning and is skipped. Never a URL.
  #
  # config.widget_script_path = Rails.root.join("app/assets/builds/mcp_ui_widgets.js")
end
