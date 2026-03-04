Rails.application.routes.draw do
  root "home#index"
  devise_for :users
  mount IronAdmin::Engine => "/admin"

  namespace :api do
    namespace :v1 do
      get "me", to: "me#show"
      resources :csv_imports, only: [ :create ]
      resources :url_validation_runs, only: [ :show ] do
        member do
          get :invalids_csv
        end
      end
    end
  end
end
