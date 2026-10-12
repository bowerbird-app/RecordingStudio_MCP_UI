# frozen_string_literal: true

module Demo
  class PageTabsComponent < ViewComponent::Base
    def initialize(data: {})
      @data = data.stringify_keys
    end

    attr_reader :data
  end
end
