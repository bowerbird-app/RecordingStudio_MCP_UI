# frozen_string_literal: true

module Demo
  # The add-row template stays outside the list. The list-item prototype has
  # to live in the <ul>, and CollectionEditor has no slot for that.
  class PageSectionsEditor < FlatPack::CollectionEditor::Component
    renders_one :list_item

    private

    def render_list
      content_tag(:ul, **list_attributes) do
        safe_join([
          (content_tag(:template, list_item.to_s.html_safe, data: { mcp_list_item: true }) if list_item?),
          safe_join(rows)
        ].compact)
      end
    end

    def render_empty
      content_tag(
        :p,
        @empty_text,
        class: "flat-pack-collection-editor-empty",
        data: {
          flat_pack__collection_editor_target: "empty",
          mcp_list_empty: true
        },
        hidden: visible_rows?
      )
    end
  end
end
