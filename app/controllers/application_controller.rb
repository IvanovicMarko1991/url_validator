class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, if: :devise_controller?

  layout :layout_by_resource

  def after_sign_in_path_for(resource)
    return "/admin" if resource.admin?
    ENV.fetch("FRONTEND_URL", "http://localhost:3001/")
  end

  private

  def layout_by_resource
    devise_controller? ? "devise" : "application"
  end
end
