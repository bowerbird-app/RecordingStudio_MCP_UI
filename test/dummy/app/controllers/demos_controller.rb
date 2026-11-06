class DemosController < ApplicationController
  DEMO_WIDGETS = %w[projects.preview projects.editor].freeze

  def show
    @project = visible_project!
    @data = Demo::ProjectPayload.call(@project)
    @inner_html = RecordingStudio::MCP_UI.render("projects.preview", data: @data)
  end

  def edit
    @project = visible_project!
    @data = Demo::ProjectPayload.call(@project)
    @inner_html = RecordingStudio::MCP_UI.render("projects.editor", data: @data)
  end

  def document
    project = visible_project!
    widget_id = params[:widget].presence || "projects.preview"
    raise ActiveRecord::RecordNotFound unless DEMO_WIDGETS.include?(widget_id)

    document = RecordingStudio::MCP_UI.package(widget_id, data: Demo::ProjectPayload.call(project))
    render html: document.html.html_safe, layout: false, content_type: document.mime_type
  end

  def save
    result = Demo::ProjectUpdate.call(
      save_params,
      actor: Current.actor,
      recording: current_root_recording
    )
    status = result[:ok] ? :ok : result_status(result[:error])
    render json: result, status: status
  end

  private

  def visible_project!
    unless Demo::ProjectAccess.visible?(actor: Current.actor, recording: current_root_recording)
      raise ActiveRecord::RecordNotFound
    end

    Project.find(params[:id])
  end

  def save_params
    params.permit(:id, :title, :description, :status, :revision).to_h
  end

  def result_status(error)
    case error
    when "unauthorized" then :forbidden
    when "conflict" then :conflict
    else :unprocessable_entity
    end
  end
end
