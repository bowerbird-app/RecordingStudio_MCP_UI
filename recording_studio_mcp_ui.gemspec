# frozen_string_literal: true

require_relative "lib/recording_studio_mcp_ui/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_mcp_ui"
  spec.version     = RecordingStudio::McpUi::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_MCP_UI"
  spec.summary     = "MCP Apps UI registration and packaging for Recording Studio"
  spec.description = "A Rails engine that lets Recording Studio gems register ViewComponent widgets, " \
                     "package MCP Apps HTML documents, and invoke existing API actions from a shared JS runtime."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_MCP_UI"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_MCP_UI/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "view_component", ">= 3.0"
end
