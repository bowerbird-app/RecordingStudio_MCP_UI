class HomeController < ApplicationController
  def index
    @project = Project.order(:created_at).first
    page = Page.find_by(title: "Launch notes")
    @page_recording = page && RecordingStudio::Recording.find_by(recordable_type: "Page", recordable_id: page.id)
  end
end
