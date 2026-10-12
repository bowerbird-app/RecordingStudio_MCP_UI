# frozen_string_literal: true

RecordingStudio::MCP_UI.configure do |config|
  # Local CSS file(s) inlined after the gem's widget.css (and Flatpack CSS, when
  # Flatpack is installed). Later files win. Missing paths are skipped. Never a URL.
  #
  # Widget tokens (override in host CSS):
  #   --mcp-ui-background  (default: transparent)
  #   --mcp-ui-color       (default: CanvasText)
  #
  # config.compiled_css_path = Rails.root.join("app/assets/stylesheets/mcp_ui_widget.css")
  # config.compiled_css_path = [
  #   Rails.root.join("app/assets/builds/tailwind.css"),
  #   Rails.root.join("app/assets/stylesheets/mcp_ui_widget.css")
  # ]
end
