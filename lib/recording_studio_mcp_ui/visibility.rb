# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Visibility
      def initialize(widget)
        @widget = widget
      end

      def available?(access_grant: nil, api: :public, version: nil)
        widget_allows?(access_grant: access_grant, api: api, version: version)
      end

      private

      def widget_allows?(access_grant:, api:, version:)
        hook = @widget.available_if
        return true unless hook

        hook.call(access_grant: access_grant, api: api, version: version, widget: @widget) == true
      end
    end
  end
end
