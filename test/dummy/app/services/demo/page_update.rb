# frozen_string_literal: true

module Demo
  class PageUpdate
    def self.call(attributes, access_grant: :allowed)
      new(attributes, access_grant: access_grant).call
    end

    def initialize(attributes, access_grant:)
      @attributes = attributes.to_h.stringify_keys
      @access_grant = access_grant
    end

    def call
      return failure("unauthorized", {}) if @access_grant == :denied

      recording = RecordingStudio::Recording.find_by(id: @attributes["id"])
      page = recording&.recordable
      return failure("not_found", { "id" => "Page not found" }) unless page.is_a?(Page)

      if @access_grant.respond_to?(:authorized?) && !@access_grant.authorized?(recording: recording, role: :edit)
        return failure("unauthorized", {})
      end

      if @attributes["revision"].present? && page.revision.to_s != @attributes["revision"].to_s
        return failure("conflict", { "revision" => "This page changed since the editor opened." })
      end

      error = content_error
      return failure("validation_failed", error) if error

      updated = recording.revise(recording, actor: actor) do |next_page|
        apply(next_page, page)
      end
      success(updated)
    rescue ActiveRecord::RecordInvalid => error
      failure("validation_failed", error.record.errors.to_hash)
    end

    private

    def apply(next_page, page)
      next_page.title = @attributes["title"] if @attributes.key?("title")
      next_page.summary = @attributes["summary"] if @attributes.key?("summary")
      next_page.sections = Demo::PageContent.sections(@attributes["sections"]) if @attributes.key?("sections")
      next_page.links = Demo::PageContent.links(@attributes["links"]) if @attributes.key?("links")
      next_page.topics = Demo::PageContent.topics(@attributes["topics"]) if @attributes.key?("topics")
      next_page.sort = @attributes["sort"] if @attributes.key?("sort")
      next_page.direction = @attributes["direction"] if @attributes.key?("direction")
      next_page.revision = page.revision + 1
    end

    def content_error
      if @attributes.key?("sections")
        Demo::PageContent.sections(@attributes["sections"]).each do |section|
          return { "sections" => "Each section needs a heading." } if section["heading"].blank?
        end
      end

      if @attributes.key?("links")
        Demo::PageContent.links(@attributes["links"]).each do |link|
          return { "links" => "Each link needs a label." } if link["label"].blank?
        end
      end

      nil
    end

    def actor
      if @access_grant.respond_to?(:actor) && @access_grant.actor.present?
        @access_grant.actor
      else
        Current.actor
      end
    end

    def success(recording)
      page = recording.recordable
      {
        ok: true,
        data: Demo::PagePayload.call(recording),
        contextUpdate: %(The user updated page #{recording.id}. The title is now "#{page.title}".)
      }
    end

    def failure(error, errors)
      { ok: false, error: error, errors: errors }
    end
  end
end
