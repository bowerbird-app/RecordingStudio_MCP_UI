# frozen_string_literal: true

module Demo
  # FlatPack::Table draws each body row and has no per-row data argument.
  # The sortable controller moves the `<tr>`, so that element is the repeatable row.
  class PageLinksTable < FlatPack::Table::Component
    private

    def row_attributes(row)
      attrs = super
      attrs[:data] = (attrs[:data] || {}).merge(mcp_row: true)
      attrs
    end
  end
end
