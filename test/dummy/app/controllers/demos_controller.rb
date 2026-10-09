class DemosController < ApplicationController
  skip_before_action :authenticate_user!, only: :document
  skip_forgery_protection only: :document

  def show
    @project = Project.find(params[:id])
    @data = Demo::ProjectPayload.call(@project)
    @inner_html = RecordingStudio::MCP_UI.render("projects.preview", data: @data)
  end

  def edit
    @project = Project.find(params[:id])
    @data = Demo::ProjectPayload.call(@project)
    @inner_html = RecordingStudio::MCP_UI.render("projects.editor", data: @data)
  end

  def document
    project = Project.find(params[:id])
    widget_id = params[:widget].presence || "projects.preview"
    document = RecordingStudio::MCP_UI.package(widget_id, data: Demo::ProjectPayload.call(project))
    render html: document.html.html_safe, layout: false, content_type: document.mime_type
  end

  def save
    result = Demo::ProjectUpdate.call(save_params, access_grant: current_access_grant)
    status = result[:ok] ? :ok : result_status(result[:error])
    render json: result, status: status
  end

  private

  def save_params
    params.permit(:id, :title, :description, :status, :revision).to_h
  end

  def current_access_grant
    params[:access_grant] == "denied" ? :denied : :allowed
  end

  def result_status(error)
    case error
    when "unauthorized" then :forbidden
    when "conflict" then :conflict
    else :unprocessable_entity
    end
  end
end
