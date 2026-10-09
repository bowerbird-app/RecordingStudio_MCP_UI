# frozen_string_literal: true

require "erb"
require "json"

module RecordingStudio
  module McpUi
    class Packager
      CSP = [
        "default-src 'none'",
        "script-src 'unsafe-inline'",
        "style-src 'unsafe-inline'",
        "img-src data: https:",
        "font-src data:",
        "connect-src 'none'",
        "object-src 'none'",
        "base-uri 'none'",
        "frame-src 'none'",
        "form-action 'none'"
      ].join("; ").freeze

      def initialize(widget)
        @widget = widget
      end

      def package(data: {}, body_html: nil, **component_options)
        payload = sanitize_data(data)
        inner = body_html || Renderer.new(@widget).render(data: payload, **component_options)
        html = document_html(inner, payload)
        Document.new(widget: @widget, html: html, data: payload)
      end

      private

      def document_html(inner_html, data)
        "#{doctype}#{head_html}#{body_html(inner_html, data)}"
      end

      def doctype
        %(<!DOCTYPE html>\n<html lang="en" data-theme="rounded">\n)
      end

      def head_html
        title = ERB::Util.html_escape(@widget.id)
        <<~HTML
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta http-equiv="Content-Security-Policy" content="#{CSP}">
            <title>#{title}</title>
            <style>#{Assets.css}</style>
          </head>
        HTML
      end

      def body_html(inner_html, data)
        config = ERB::Util.json_escape(JSON.generate(widget_config(data)))
        <<~HTML
          <body class="mcp-ui-body">
            <div id="mcp-ui-root">#{inner_html}</div>
            <script type="application/json" id="mcp-ui-config">#{config}</script>
            <script>#{Assets.javascript}</script>
          </body>
          </html>
        HTML
      end

      def widget_config(data)
        {
          widgetId: @widget.id,
          uri: @widget.resource_uri,
          mode: @widget.mode,
          version: @widget.version,
          actions: @widget.actions.keys,
          data: data
        }
      end

      def sanitize_data(data)
        return sanitize_hash(data) if data.is_a?(Hash)
        return data.map { |value| sanitize_data(value) } if data.is_a?(Array)
        return data if scalar?(data)

        data.to_s
      end

      def scalar?(data)
        data.is_a?(Numeric) || [true, false, nil].include?(data)
      end

      def sanitize_hash(data)
        data.each_with_object({}) do |(key, value), memo|
          next if secret_key?(key)

          memo[key.to_s] = sanitize_data(value)
        end
      end

      def secret_key?(key)
        key.to_s.match?(/token|secret|password|authorization|api[_-]?key|credential/i)
      end
    end
  end
end
