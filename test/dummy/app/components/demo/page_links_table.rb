# frozen_string_literal: true

module Demo
  # FlatPack::Table draws each body row from Ruby data and has no row template.
  # <template> is allowed in a <tbody>, so the tool result clones one row there.
  class PageLinksTable < FlatPack::Table::Component
    private

    def render_body
      tag.tbody(**tbody_attributes) do
        safe_join([
          tag.template(render_row(template_row), data: { mcp_list_item: true }),
          render_empty_state
        ])
      end
    end

    def container_attributes
      attrs = super
      attrs[:data] = (attrs[:data] || {}).merge(mcp_reconnect: "flat-pack--table-sortable")
      attrs
    end

    def tbody_attributes
      attrs = super
      attrs[:data] = (attrs[:data] || {}).merge(mcp_list: "links")
      attrs
    end

    def render_empty_state
      tag.tr(data: { mcp_list_empty: true }) do
        tag.td(
          colspan: column_count,
          class: "#{body_cell_classes} text-center text-[var(--table-empty-state-text-color)]"
        ) do
          fp_t("table.empty")
        end
      end
    end

    def template_row
      { "id" => "", "label" => "", "url" => "" }
    end

    def row_attributes(row)
      attrs = super
      attrs[:data] = (attrs[:data] || {}).merge(mcp_row: true, mcp_attr_data_id: "id")
      attrs
    end
  end
end
