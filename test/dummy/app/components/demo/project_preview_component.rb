# frozen_string_literal: true

module Demo
  class ProjectPreviewComponent < ViewComponent::Base
    def initialize(data: {})
      @data = data.stringify_keys
    end

    def title
      @data["title"]
    end

    def description
      @data["description"]
    end

    def status
      @data["status"]
    end
  end
end
