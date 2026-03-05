# frozen_string_literal: true

module EventContext
  extend ActiveSupport::Concern

  included do
    before_action :set_event_context
  end

  private

  def set_event_context
    return unless Rails.respond_to?(:event)

    Rails.event.set_context(
      request_id: request.request_id,
      user_id: respond_to?(:current_user) ? current_user&.id : nil,
      ip: request.remote_ip,
      user_agent: request.user_agent
    )
  end
end
