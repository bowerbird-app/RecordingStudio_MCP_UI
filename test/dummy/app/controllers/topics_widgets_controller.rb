# frozen_string_literal: true

class TopicsWidgetsController < ApplicationController
  skip_before_action :authenticate_user!, only: :document

  WIDGETS = %w[pages.topics pages.tabs].freeze

  def show
  end

  def document
    widget_id = WIDGETS.include?(params[:widget]) ? params[:widget] : "pages.topics"
    packaged = RecordingStudio::MCP_UI.package(widget_id, data: {})
    render html: packaged.html.html_safe, layout: false, content_type: packaged.mime_type
  end
end
