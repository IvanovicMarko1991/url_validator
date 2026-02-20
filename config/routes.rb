Rails.application.routes.draw do
  resources :csv_imports, only: [ :create ]
  resources :url_validation_runs, only: [ :show ]
end
