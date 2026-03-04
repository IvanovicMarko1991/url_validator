IronAdmin.configure do |config|
  config.title = "URL Validator Admin"

  config.authenticate do |controller|
    controller.authenticate_user!

    unless controller.current_user&.admin?
      controller.redirect_to controller.main_app.root_path, alert: "Not authorized"
    end
  end
end
