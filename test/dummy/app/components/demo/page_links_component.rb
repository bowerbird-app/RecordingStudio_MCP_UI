# frozen_string_literal: true

module Demo
  class PageLinksComponent < PageWidgetComponent
    include McpWidgetChrome

    def table
      component = PageLinksTable.new(
        data: [],
        sort: sort_key,
        direction: sort_direction,
        base_url: sort_base_url,
        min_width: :none,
        draggable_rows: true,
        row_id: ->(row) { row["id"] }
      )
      component.column(title: "Reorder") do |_row|
        helpers.tag.span(
          "⋮",
          aria: { hidden: true },
          class: "inline-flex text-[var(--surface-muted-content-color)] cursor-grab"
        )
      end
      component.column(title: "Label", sortable: true, sort_key: :label) do |_row|
        helpers.safe_join([
          helpers.tag.input(type: "hidden", name: "links[][id]", value: "", data: { mcp_field: true }),
          link_field("links[][label]", "Label", "link-$index-label")
        ])
      end
      component.column(title: "Link", sortable: true, sort_key: :url) do |_row|
        link_field("links[][url]", "Link", "link-$index-url")
      end
      component
    end

    private

    def link_field(name, label, attr_id)
      render(FlatPack::TextInput::Component.new(
        name: name,
        label: nil,
        value: "",
        chrome: :cell,
        aria: { label: label },
        data: { mcp_field: true, flat_pack_validate: false, mcp_attr_id: attr_id }
      ))
    end

    def sort_key
      key = data["sort"].to_s
      Page::SORTS.include?(key) ? key : "label"
    end

    def sort_direction
      direction = data["direction"].to_s
      Page::DIRECTIONS.include?(direction) ? direction : "asc"
    end

    def sort_base_url
      return if data["id"].blank?

      Rails.application.routes.url_helpers.document_page_demo_path(data["id"], widget: "pages.links")
    end
  end
end
