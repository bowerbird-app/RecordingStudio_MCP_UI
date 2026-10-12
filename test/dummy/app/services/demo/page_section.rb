# frozen_string_literal: true

module Demo
  class PageSection
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :id
    attribute :heading
    attribute :body

    def persisted?
      id.present?
    end

    # Rails turns object[] into object[to_param]. An empty index keeps sections[][id].
    def to_param
      nil
    end
  end
end
