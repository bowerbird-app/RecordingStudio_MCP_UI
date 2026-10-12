# frozen_string_literal: true

module Demo
  # Error and status lines the editor runtime fills by setting textContent.
  # The attribute stays on the Alert root so data-mcp-error and data-mcp-status keep working.
  module McpWidgetChrome
    # FlatPack Content and Badge reject blank text. This mark is invisible and not blank.
    def mcp_reading(value)
      value.presence || "\u2060"
    end

    def mcp_error(field)
      FlatPack::Alert::Component.new(
        style: :danger,
        icon: false,
        size: :sm,
        hidden: true,
        data: { mcp_error: field }
      )
    end

    def mcp_status
      FlatPack::Alert::Component.new(
        style: :info,
        icon: false,
        size: :sm,
        hidden: true,
        class: "mcp-ui-status",
        data: { mcp_status: true }
      )
    end
  end
end
