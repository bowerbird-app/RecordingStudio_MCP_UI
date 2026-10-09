# frozen_string_literal: true

RecordingStudio::MCP_UI.configure do |config|
  # Optional path to compiled host CSS inlined into packaged MCP Apps documents.
  # config.compiled_css_path = Rails.root.join("app/assets/builds/tailwind.css")

  # MCP or a test adapter should assign an executor that dispatches to RecordingStudio API.
  # config.action_executor = ->(request) { RecordingStudioMcp.dispatch_widget_action(request) }

  # Optional extra visibility check. MCP should combine access grants, API surface, and Accessible.
  # config.visibility_checker = ->(widget:, access_grant:, **) { true }
end
