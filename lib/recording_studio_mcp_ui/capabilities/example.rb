# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    # Example opt-in mixin retained from the addon template conventions.
    #
    # Host models opt in with:
    #   include RecordingStudio::Capabilities::Example.to(label: "demo")
    module Example
      def self.to(**)
        RecordingStudio::Capabilities.include_for(:example, **)
      end
    end
  end
end

RecordingStudio.register_capability(
  :example,
  source: RecordingStudio::Capabilities::Example
)
