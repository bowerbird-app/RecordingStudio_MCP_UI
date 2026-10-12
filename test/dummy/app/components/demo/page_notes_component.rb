# frozen_string_literal: true

module Demo
  class PageNotesComponent < PageWidgetComponent
    def note_items
      return sections if sections.any?

      [{ "id" => "empty", "heading" => "Nothing here yet", "body" => "Add a section to get going." }]
    end
  end
end
