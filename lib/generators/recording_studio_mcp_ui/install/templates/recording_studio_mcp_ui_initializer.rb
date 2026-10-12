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
  # Stimulus controllers inlined into packaged widgets. nil (default) uses every
  # local controllers/*_controller pin from the host import map. false opts out.
  # A list of identifiers or module names limits the bundle.
  #
  # config.stimulus_controllers = false
  # config.stimulus_controllers = %w[flat-pack--tabs flat-pack--collection-editor]
end
