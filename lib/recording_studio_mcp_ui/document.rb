# frozen_string_literal: true

module RecordingStudio
  module McpUi
    class Document
      MIME_TYPE = Widget::MIME_TYPE

      attr_reader :widget, :html, :data

      def initialize(widget:, html:, data:)
        @widget = widget
        @html = html
        @data = data
      end

      def uri
        widget.resource_uri
      end

      def mime_type
        MIME_TYPE
      end

      def metadata
        widget.metadata
      end

      def to_mcp_resource
        {
          uri: uri,
          name: widget.id,
          description: widget.description,
          mimeType: mime_type,
          text: html,
          _meta: { ui: { csp: default_csp } }
        }
      end

      def default_csp
        {
          connectDomains: [],
          resourceDomains: [],
          frameDomains: [],
          baseUriDomains: []
        }
      end
    end
  end
end
