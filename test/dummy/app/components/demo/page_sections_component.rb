# frozen_string_literal: true

module Demo
  class PageSectionsComponent < PageWidgetComponent
    include McpWidgetChrome

    def section_form(section)
      object = PageSection.new(id: section["id"], heading: section["heading"], body: section["body"])
      McpFieldsBuilder.new("sections[]", object, helpers, {})
    end

    def heading_input(section, token, attr_id: nil)
      cell_input(section, token, "heading", "Heading", attr_id: attr_id)
    end

    def body_input(section, token, attr_id: nil)
      cell_input(section, token, "body", "Body", attr_id: attr_id)
    end

    def list_row
      blank = { "id" => "", "heading" => "", "body" => "" }
      row = FlatPack::CollectionEditor::Row::Component.new(
        form: section_form(blank),
        persisted: true,
        record_id: "LIST_ITEM",
        data: { mcp_row: true, mcp_attr_data_id: "id" }
      )
      row.with_field { render heading_input(blank, "LIST_ITEM", attr_id: "section-$index-heading") }
      row.with_field { render body_input(blank, "LIST_ITEM", attr_id: "section-$index-body") }
      render row
    end

    private

    # Headed collection editor rows take chrome: :cell, same as the FlatPack text-line demo.
    def cell_input(section, token, key, label, attr_id: nil)
      data = { mcp_field: true, flat_pack_validate: false }
      data[:mcp_attr_id] = attr_id if attr_id
      FlatPack::TextInput::Component.new(
        name: "sections[][#{key}]",
        id: "section_#{token}_#{key}",
        label: label,
        value: section[key],
        chrome: :cell,
        data: data
      )
    end
  end
end
