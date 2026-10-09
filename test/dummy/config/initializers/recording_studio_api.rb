# frozen_string_literal: true

require Rails.root.join("app/services/demo/project_arguments")
require Rails.root.join("app/services/demo/project_show")
require Rails.root.join("app/services/demo/project_api_update")

RecordingStudioApi.configure do |config|
  config.openapi_title = "Recording Studio API"
  config.openapi_description = "Resource server for Recording Studio. MCP calls the same actions."
  config.documentation_enabled = true
  config.documentation_access = :public
  config.layout_name = "recording_studio/default_layout"
  config.admin_layout_name = "recording_studio/default_layout"
  config.rate_limit_oauth_enabled = false if config.respond_to?(:rate_limit_oauth_enabled=)
  config.rate_limit_api_pre_auth_enabled = false if config.respond_to?(:rate_limit_api_pre_auth_enabled=)
  config.rate_limit_api_enabled = false if config.respond_to?(:rate_limit_api_enabled=)
  config.api_request_logging_enabled = false if config.respond_to?(:api_request_logging_enabled=)
  config.api_management_authorization_required = false if config.respond_to?(:api_management_authorization_required=)
end

RecordingStudioApi.register_endpoint(
  "projects.show",
  http_verb: :get,
  path: "projects/:id",
  ui: "projects.preview",
  input_contract: {
    fields: {
      id: { type: :string, required: true }
    }
  },
  handler: Demo::ProjectShow
)

RecordingStudioApi.register_endpoint(
  "projects.update",
  http_verb: :patch,
  path: "projects/:id",
  ui: "projects.editor",
  input_contract: {
    fields: {
      id: { type: :string, required: true },
      title: { type: :string, required: false },
      description: { type: :string, required: false },
      status: { type: :string, required: false },
      revision: { type: :integer, required: false }
    }
  },
  handler: Demo::ProjectApiUpdate
)
