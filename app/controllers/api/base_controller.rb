module Api
  class BaseController < ActionController::Base
    protect_from_forgery with: :null_session

    before_action :authenticate_user!
    respond_to :json
  end
end
