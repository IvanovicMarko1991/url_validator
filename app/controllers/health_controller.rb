# frozen_string_literal: true

class HealthController < ActionController::API
  def healthz
    render json: { status: "ok" }, status: :ok
  end

  def readyz
    checks = {
      db: db_ok?,
      redis: redis_ok?
    }

    if checks.values.all?
      render json: { status: "ok", checks: checks }, status: :ok
    else
      render json: { status: "not_ready", checks: checks }, status: :service_unavailable
    end
  end

  private

  def db_ok?
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue StandardError
    false
  end

  def redis_ok?
    Sidekiq.redis { |r| r.ping == "PONG" }
  rescue StandardError
    false
  end
end
