# frozen_string_literal: true

module Demo
  # FlatPack::Table accepts `tbody_data`. It has no row template, no data
  # attribute on the empty row, and no extra attributes on a body row.
  class PageLinksTable < FlatPack::Table::Component
    private

    def render_body
      tag.tbody(**tbody_attributes) do
        safe_join([
          tag.template(render_row("id" => "", "label" => "", "url" => ""), data: { mcp_list_item: true }),
          render_empty_state
        ])
      end
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

    # Table sets the sortable target and `data-id` only. Save order and the
    # binder's id attribute have no option on the component.
    def row_attributes(row)
      attrs = super
      attrs[:data] = (attrs[:data] || {}).merge(mcp_row: true, mcp_attr_data_id: "id")
      attrs
    end
  end
end
