IronAdmin.configure do |config|
  config.title = "URL Validator Admin"

  config.authenticate do |controller|
    next if Rails.env.development? || Rails.env.test?

    controller.authenticate_or_request_with_http_basic("Admin") do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, ENV.fetch("ADMIN_USER")) &
        ActiveSupport::SecurityUtils.secure_compare(password, ENV.fetch("ADMIN_PASSWORD"))
    end
  end
end
