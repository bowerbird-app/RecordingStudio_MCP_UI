# frozen_string_literal: true

module Demo
  module PageContent
    module_function

    def sections(value)
      Array(value).filter_map { |row| section_row(row) }
    end

    def links(value)
      Array(value).filter_map { |row| link_row(row) }
    end

    def topics(value)
      Array(value).filter_map { |topic| topic.to_s.strip.presence }.uniq
    end

    def section_row(row)
      hash = stringify(row)
      return if hash.nil?
      return if destroyed?(hash["_destroy"])

      heading = hash["heading"].to_s.strip
      body = hash["body"].to_s
      id = hash["id"].to_s.strip
      return if id.blank? && heading.blank? && body.blank?

      id = SecureRandom.uuid if id.blank?
      { "id" => id, "heading" => heading, "body" => body }
    end

    def link_row(row)
      hash = stringify(row)
      return if hash.nil?
      return if destroyed?(hash["_destroy"])

      label = hash["label"].to_s.strip
      url = hash["url"].to_s.strip
      id = hash["id"].to_s.strip
      return if id.blank? && label.blank? && url.blank?

      id = SecureRandom.uuid if id.blank?
      { "id" => id, "label" => label, "url" => url }
    end

    def destroyed?(flag)
      flag == true || flag.to_s == "1" || flag.to_s == "true"
    end

    def stringify(row)
      return row.stringify_keys if row.respond_to?(:stringify_keys)
      return row.to_h.stringify_keys if row.respond_to?(:to_h)

      nil
    end
  end
end
