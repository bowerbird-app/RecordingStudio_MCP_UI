class PageDemosController < ApplicationController
  skip_before_action :authenticate_user!, only: :document
  skip_forgery_protection only: :document

  def show
    @recording = find_recording
    @data = Demo::PagePayload.call(@recording)
  end

  def document
    recording = find_recording
    widget_id = params[:widget].presence || "pages.sections"
    data = Demo::PagePayload.call(recording)
    data = sorted_link_data(data) if widget_id == "pages.links"
    document = RecordingStudio::MCP_UI.package(widget_id, data: data)
    render html: document.html.html_safe, layout: false, content_type: document.mime_type
  end

  def save
    result = Demo::PageUpdate.call(save_params, access_grant: current_access_grant)
    status = result[:ok] ? :ok : result_status(result[:error])
    render json: result, status: status
  end

  private

  def find_recording
    recording = RecordingStudio::Recording.find(params[:id])
    raise ActiveRecord::RecordNotFound unless recording.recordable.is_a?(Page)

    recording
  end

  def sorted_link_data(data)
    sort = params[:sort].to_s
    direction = params[:direction].to_s
    data["sort"] = sort if Page::SORTS.include?(sort)
    data["direction"] = direction if Page::DIRECTIONS.include?(direction)
    key = Page::SORTS.include?(data["sort"].to_s) ? data["sort"].to_s : "label"
    dir = Page::DIRECTIONS.include?(data["direction"].to_s) ? data["direction"].to_s : "asc"
    rows = Array(data["links"]).sort_by { |row| row[key].to_s.downcase }
    data["links"] = dir == "desc" ? rows.reverse : rows
    data["sort"] = key
    data["direction"] = dir
    data
  end

  def save_params
    params.permit(
      :id,
      :title,
      :summary,
      :sort,
      :direction,
      :revision,
      sections: [ :id, :heading, :body, :_destroy ],
      links: [ :id, :label, :url, :_destroy ],
      topics: []
    ).to_h
  end

  def current_access_grant
    params[:access_grant] == "denied" ? :denied : :allowed
  end

  def result_status(error)
    case error
    when "unauthorized" then :forbidden
    when "not_found" then :not_found
    when "conflict" then :conflict
    else :unprocessable_entity
    end
  end
end
