# frozen_string_literal: true

module Demo
  class McpFieldsBuilder < ActionView::Helpers::FormBuilder
    def hidden_field(method, options = {})
      options = options.dup
      data = (options[:data] || {}).dup
      data[:mcp_field] = true
      options[:data] = data
      super
    end
  end
end
