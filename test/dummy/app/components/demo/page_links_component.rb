# frozen_string_literal: true

module Demo
  class PageLinksComponent < PageWidgetComponent
    include McpWidgetChrome

    def table
      component = PageLinksTable.new(
        data: sorted_links,
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
      component.column(title: "Label", sortable: true, sort_key: :label) do |row|
        helpers.safe_join([
          helpers.tag.input(type: "hidden", name: "links[][id]", value: row["id"], data: { mcp_field: true }),
          helpers.tag.input(type: "hidden", name: "links[][label]", value: row["label"], data: { mcp_field: true }),
          render(FlatPack::Content::Component.new(class: "text-[var(--surface-content-color)]")) do
            mcp_reading(row["label"])
          end
        ])
      end
      component.column(title: "Link", sortable: true, sort_key: :url) do |row|
        helpers.safe_join([
          helpers.tag.input(type: "hidden", name: "links[][url]", value: row["url"], data: { mcp_field: true }),
          link_url(row)
        ])
      end
      component
    end

    private

    def link_url(row)
      url = row["url"].to_s
      if url.match?(/\Ahttps?:/i)
        render(FlatPack::Link::Component.new(href: url)) { url }
      else
        render(FlatPack::Content::Component.new) { mcp_reading(url) }
      end
    end

    def sorted_links
      rows = links.sort_by { |row| row[sort_key].to_s.downcase }
      sort_direction == "desc" ? rows.reverse : rows
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
