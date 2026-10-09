# frozen_string_literal: true

Rails.application.config.to_prepare do
  RecordingStudio::MCP_UI.reset_registry!

  RecordingStudio::MCP_UI.register(
    "projects.preview",
    component: Demo::ProjectPreviewComponent,
    description: "Displays a project card",
    mode: :read,
    version: "1.0.0"
  )

  RecordingStudio::MCP_UI.register(
    "projects.editor",
    component: Demo::ProjectEditorComponent,
    description: "Edit a project",
    mode: :edit,
    version: "1.0.0",
    actions: { save: "projects.update" }
  )

  RecordingStudio::MCP_UI.configure do |config|
    config.compiled_css_path = Rails.root.join("app/assets/builds/tailwind.css")
  end
end
