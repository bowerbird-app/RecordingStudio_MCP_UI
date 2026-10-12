# frozen_string_literal: true

module Demo
  class PageWidgetComponent < ViewComponent::Base
    def initialize(data: {})
      @data = data.stringify_keys
    end

    attr_reader :data

    def title
      data["title"].to_s
    end

    def summary
      data["summary"].to_s
    end

    def sections
      PageContent.sections(data["sections"])
    end

    def links
      PageContent.links(data["links"])
    end

    def topics
      PageContent.topics(data["topics"])
    end
  end
end
