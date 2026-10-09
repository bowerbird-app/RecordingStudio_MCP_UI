# frozen_string_literal: true

module Demo
  class ActionAdapter
    def self.call(request)
      case request.api_action
      when "projects.update"
        ProjectUpdate.call(request.arguments.merge("revision" => request.revision || request.arguments["revision"]),
                           access_grant: request.access_grant || :allowed)
      else
        { ok: false, error: "unknown_api_action" }
      end
    end
  end
end
