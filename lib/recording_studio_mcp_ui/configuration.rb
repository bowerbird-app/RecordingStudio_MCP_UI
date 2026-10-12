# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Configuration
      attr_accessor :compiled_css_path
      attr_reader :hooks, :registry, :stimulus_controllers

      def initialize
        @hooks = RecordingStudio::Hooks.new
        @registry = Registry.new
        @compiled_css_path = nil
        @stimulus_controllers = nil
      end

      def stimulus_controllers=(value)
        @stimulus_controllers = normalize_stimulus_controllers(value)
      end

      def to_h
        {
          compiled_css_path: compiled_css_path,
          stimulus_controllers: stimulus_controllers,
          hooks_registered: hooks.registered_counts
        }
      end

      def merge!(hash)
        return unless hash.respond_to?(:each)

        hash.each do |key, value|
          setter = "#{key}="
          public_send(setter, value) if respond_to?(setter)
        end
      end

      private

      def normalize_stimulus_controllers(value)
        return nil if value.nil?
        return false if value == false

        Array(value).map(&:to_s)
      end
    end
  end
end
