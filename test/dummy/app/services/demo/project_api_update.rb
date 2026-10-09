# frozen_string_literal: true

module Demo
  class ProjectApiUpdate
    def self.call(context)
      attributes = ProjectArguments.slice(context, :id, :title, :description, :status, :revision)
      result = ProjectUpdate.call(attributes, access_grant: :allowed)
      return result if result[:ok]

      { json: result, status: status_for(result[:error]) }
    end

    def self.status_for(error)
      case error
      when "unauthorized" then :forbidden
      when "conflict" then :conflict
      else :unprocessable_entity
      end
    end
  end
end
