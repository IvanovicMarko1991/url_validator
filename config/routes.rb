Rails.application.routes.draw do
  resources :csv_imports, only: [ :create ]
  resources :url_validation_runs, only: [ :show ] do
    member do
      get :invalids_csv
    end
  end
end
