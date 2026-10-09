# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Registry
      def initialize
        @widgets = {}
        @mutex = Mutex.new
      end

      def register(id, **attributes)
        widget = Widget.new(id: id, **attributes)

        @mutex.synchronize do
          existing = @widgets[widget.id]
          if existing && !existing.same_contract?(widget)
            raise DuplicateWidgetError, "Widget already registered: #{widget.id}"
          end

          @widgets[widget.id] = widget
        end

        widget
      end

      def find(id)
        widget = @mutex.synchronize { @widgets[id.to_s] }
        raise UnknownWidgetError, "Unknown widget: #{id.inspect}" unless widget

        widget
      end

      def fetch(id)
        find(id)
      end

      def list(mode: nil, prefix: nil, version: nil)
        @mutex.synchronize { @widgets.values }.select { |widget| match?(widget, mode, prefix, version) }
      end

      def reset!
        @mutex.synchronize { @widgets.clear }
      end

      def size
        @mutex.synchronize { @widgets.size }
      end

      private

      def match?(widget, mode, prefix, version)
        (mode.nil? || widget.mode == mode.to_sym) &&
          (prefix.nil? || widget.id.start_with?(prefix.to_s)) &&
          (version.nil? || widget.version == version.to_s)
      end
    end
  end
end
