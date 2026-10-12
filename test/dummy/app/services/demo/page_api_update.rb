# frozen_string_literal: true

module Demo
  class PageApiUpdate
    def self.call(context)
      attributes = PageArguments.slice(
        context,
        :id,
        :title,
        :summary,
        :sections,
        :links,
        :topics,
        :sort,
        :direction,
        :revision
      )
      PageUpdate.call(attributes, access_grant: context.access_grant)
    end
  end
end
