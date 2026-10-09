# frozen_string_literal: true

module Demo
  class ProjectApiUpdate
    def self.call(context)
      attributes = ProjectArguments.slice(context, :id, :title, :description, :status, :revision)
      ProjectUpdate.call(attributes, access_grant: :allowed)
    end
  end
end
