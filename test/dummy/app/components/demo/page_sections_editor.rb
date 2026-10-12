# frozen_string_literal: true

module Demo
  # FlatPack::CollectionEditor renders Ruby rows into the list. The add-row
  # template stays outside that list. <template> is allowed in a <ul>, so the
  # tool result clones one row there.
  class PageSectionsEditor < FlatPack::CollectionEditor::Component
    def initialize(list_row:, **system_arguments)
      @list_row = list_row
      super(**system_arguments)
    end

    private

    def render_list
      content_tag(:ul, **list_attributes) do
        content_tag(:template, @list_row.call, data: { mcp_list_item: true })
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
        }
      )
    end
  end
end
