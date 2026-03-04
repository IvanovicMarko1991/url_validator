module Api
  module V1
    class MeController < Api::BaseController
      def show
        render json: { id: current_user.id, email: current_user.email, role: current_user.role }
      end
    end
  end
end
