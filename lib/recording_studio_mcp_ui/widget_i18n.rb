# frozen_string_literal: true

module RecordingStudio
  module McpUi
    module WidgetI18n
      module_function

      def for_config
        {
          "editor" => editor_messages
        }
      end

      def editor_messages
        {
          "saving" => translate("editor.saving", "Saving…"),
          "saved" => translate("editor.saved", "Saved"),
          "save_failed" => translate("editor.save_failed", "Save failed")
        }
      end

      def translate(key, english, **interpolations)
        I18n.t("recording_studio.mcp_ui.#{key}", default: english, **interpolations)
      end
    end
  end
end
