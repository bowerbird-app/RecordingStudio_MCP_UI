# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Visibility
      def initialize(widget)
        @widget = widget
      end

      def available?(access_grant: nil, api: :public, version: nil)
        return false unless widget_allows?(access_grant: access_grant, api: api, version: version)

        checker = RecordingStudio::MCP_UI.configuration.visibility_checker
        return true unless checker

        checker.call(widget: @widget, access_grant: access_grant, api: api, version: version) == true
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
