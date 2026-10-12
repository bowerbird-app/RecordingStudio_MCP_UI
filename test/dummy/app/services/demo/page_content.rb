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
      return unless allowed_url?(url)

      id = SecureRandom.uuid if id.blank?
      { "id" => id, "label" => label, "url" => url }
    end

    def link_error(value)
      Array(value).each do |row|
        hash = stringify(row)
        next if hash.nil?
        next if destroyed?(hash["_destroy"])

        label = hash["label"].to_s.strip
        url = hash["url"].to_s.strip
        id = hash["id"].to_s.strip
        next if id.blank? && label.blank? && url.blank?

        return "Each link needs a label." if label.blank?
        return "Each link needs an http, https, or relative URL." unless allowed_url?(url)
      end

      nil
    end

    def allowed_url?(value)
      stripped = value.to_s.gsub(/[\u0000-\u0020\u007F]/, "")
      return true if stripped.blank?
      return false if stripped.start_with?("\\", "//")

      scheme = stripped[/\A([A-Za-z][A-Za-z0-9+.-]*):/, 1]
      return true if scheme.nil?

      scheme.casecmp("http").zero? || scheme.casecmp("https").zero?
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
