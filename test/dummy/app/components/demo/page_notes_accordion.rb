# frozen_string_literal: true

module Demo
  # FlatPack::Accordion collects items in Ruby and has no item template.
  # One item lives in a template so the tool result can clone it.
  class PageNotesAccordion < FlatPack::Accordion::Component
    def call
      content
      content_tag(:div, **list_container_attributes) do
        safe_join([
          content_tag(:template, render_item(placeholder_item), data: { mcp_list_item: true }),
          render(FlatPack::EmptyState::Component.new(
            title: "Nothing here yet.",
            size: :sm,
            data: { mcp_list_empty: true }
          ))
        ])
      end
    end

    private

    def list_container_attributes
      attrs = container_attributes
      attrs[:data] = (attrs[:data] || {}).merge(mcp_list: "sections")
      attrs
    end

    def placeholder_item
      { id: "note", title: "", left_slot: nil, open: false, content: "" }
    end

    def render_item_label(_item)
      content_tag(:span, class: "flex items-center gap-2 min-w-0") do
        content_tag(:span, "", class: size_config.fetch(:title), data: { mcp_text: "heading" })
      end
    end

    def render_item_content(item)
      content_tag(:div, **item_content_attributes(item)) do
        content_tag(:div, class: "p-[var(--accordion-content-padding)]") do
          render(FlatPack::Content::Component.new(data: { mcp_text: "body" })) { "\u2060" }
        end
      end
    end

    def item_trigger_attributes(item)
      attrs = super
      attrs[:data] = (attrs[:data] || {}).merge(
        mcp_attr_id: "note-$index-trigger",
        mcp_attr_aria_controls: "note-$index-content"
      )
      attrs
    end

    def item_content_attributes(item)
      attrs = super
      attrs[:aria] = { expanded: "false" }
      attrs[:data] = (attrs[:data] || {}).merge(mcp_attr_id: "note-$index-content")
      attrs
    end
  end
end
