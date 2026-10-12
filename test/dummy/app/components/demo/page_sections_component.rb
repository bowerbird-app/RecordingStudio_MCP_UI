# frozen_string_literal: true

module Demo
  class PageSectionsComponent < PageWidgetComponent
    include McpWidgetChrome

    def section_form(section)
      object = PageSection.new(id: section["id"], heading: section["heading"], body: section["body"])
      McpFieldsBuilder.new("sections[]", object, helpers, {})
    end

    def heading_input(section, token)
      cell_input(section, token, "heading", "Heading")
    end

    def body_input(section, token)
      cell_input(section, token, "body", "Body")
    end

    private

    # Headed collection editor rows take chrome: :cell, same as the FlatPack text-line demo.
    def cell_input(section, token, key, label)
      FlatPack::TextInput::Component.new(
        name: "sections[][#{key}]",
        id: "section_#{token}_#{key}",
        label: label,
        value: section[key],
        chrome: :cell,
        data: { mcp_field: true, flat_pack_validate: false }
      )
    end
  end
end
