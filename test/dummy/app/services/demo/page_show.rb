# frozen_string_literal: true

module Demo
  class PageShow
    def self.call(context)
      recording = RecordingStudio::Recording.find(PageArguments.fetch(context, "id"))
      page = recording.recordable
      raise ActiveRecord::RecordNotFound unless page.is_a?(Page)

      grant = context.access_grant
      if grant.respond_to?(:authorized?) && !grant.authorized?(recording: recording, role: :view)
        return { "ok" => false, "error" => "unauthorized", "errors" => {} }
      end

      PagePayload.call(recording)
    end
  end
end
