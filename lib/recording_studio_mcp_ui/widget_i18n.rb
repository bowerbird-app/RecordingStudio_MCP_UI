# frozen_string_literal: true

module RecordingStudio
  module McpUi
    module WidgetI18n
      module_function

      def for_config
        {
          "editor" => editor_messages,
          "runtime" => runtime_messages
        }
      end

      def editor_messages
        {
          "saving" => translate("editor.saving", "Saving…"),
          "saved" => translate("editor.saved", "Saved"),
          "save_failed" => translate("editor.save_failed", "Save failed")
        }
      end

      def runtime_messages
        {
          "tool_call_failed" => translate("runtime.tool_call_failed", "Tool call failed"),
          "unknown_action_alias" => unknown_action_alias_message,
          "no_action_transport" => translate("runtime.no_action_transport", "No action transport")
        }
      end

      def unknown_action_alias_message
        # Packaged JS fills %{alias}; pass the same token so I18n leaves it intact.
        template = "Unknown action alias: %{alias}" # rubocop:disable Style/FormatStringToken
        placeholder = "%{alias}" # rubocop:disable Style/FormatStringToken
        translate("runtime.unknown_action_alias", template, alias: placeholder)
      end

      def translate(key, english, **interpolations)
        I18n.t("recording_studio.mcp_ui.#{key}", default: english, **interpolations)
      end
    end
  end
end
