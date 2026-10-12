# frozen_string_literal: true

module Demo
  class PagePayload
    def self.call(recording)
      page = recording.recordable
      {
        "id" => recording.id,
        "title" => page.title,
        "summary" => page.summary.to_s,
        "sections" => Demo::PageContent.sections(page.sections),
        "links" => Demo::PageContent.links(page.links),
        "topics" => Demo::PageContent.topics(page.topics),
        "sort" => page.sort,
        "direction" => page.direction,
        "revision" => page.revision
      }
    end
  end
end
