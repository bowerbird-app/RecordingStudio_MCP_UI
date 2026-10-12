# frozen_string_literal: true

require "json"
require "recording_studio_mcp_ui/import_map_catalog"
require "recording_studio_mcp_ui/module_inliner"
require "recording_studio_mcp_ui/stimulus_bundle/graph"
require "recording_studio_mcp_ui/stimulus_bundle/script"

module RecordingStudio
  module McpUi
    # Inlines Stimulus and the host's local Stimulus controllers into one classic script.
    # The widget CSP has no network, so remote static imports are skipped instead of fetched.
    class StimulusBundle
      include StimulusBundleGraph
      include StimulusBundleScript

      STIMULUS = "@hotwired/stimulus"
      SCRIPT_CLOSE = %r{</script}i

      def self.javascript(configuration = RecordingStudio::MCP_UI.configuration, catalog: nil)
        return "" if configuration.stimulus_controllers == false

        catalog ||= ImportMapCatalog.from_rails
        cache[cache_key(configuration, catalog)] ||= new(configuration, catalog).to_js
      end

      def self.reset_cache!
        @cache = {}
      end

      def self.cache_key(configuration, catalog)
        [VERSION, configuration.stimulus_controllers, catalog.fingerprint]
      end

      def self.cache
        @cache ||= {}
      end

      def self.identifier_for(module_name)
        module_name.to_s.sub(%r{\Acontrollers/}, "").sub("_controller", "").gsub("/", "--").tr("_", "-")
      end

      def initialize(configuration, catalog)
        @configuration = configuration
        @catalog = catalog
        @notes = []
      end

      def to_js
        stimulus = @catalog.find(StimulusBundle::STIMULUS)
        return missing_stimulus if stimulus.nil? || !stimulus.local?

        chosen = selectable
        return notes_js if chosen.empty?

        escape_script(wrap(closure_for(stimulus, chosen)))
      end
    end
  end
end
