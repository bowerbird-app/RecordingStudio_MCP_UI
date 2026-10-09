# frozen_string_literal: true

require "action_controller"
require "action_view"

module RecordingStudio
  module McpUi
    class Renderer
      def initialize(widget)
        @widget = widget
      end

      def render(data: {}, **component_options)
        component = instantiate(data, component_options)
        view_context.render(component)
      end

      private

      def instantiate(data, component_options)
        component_class = @widget.component
        payload = data.respond_to?(:stringify_keys) ? data.stringify_keys : data
        component_class.new(data: payload, **component_options)
      end

      def view_context
        controller = ActionController::Base.new
        controller.request ||= ActionDispatch::TestRequest.create
        controller.view_context
      end
    end
  end
end
