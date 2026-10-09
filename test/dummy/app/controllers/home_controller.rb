class HomeController < ApplicationController
  def index
    @project = Project.order(:created_at).first
  end
end
