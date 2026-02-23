Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :csv_imports, only: [ :create ]
      resources :url_validation_runs, only: [ :show ] do
        member do
          get :invalids_csv
        end
      end
    end
  end
end
