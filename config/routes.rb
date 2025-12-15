Rails.application.routes.draw do
  root "drive_sessions#index"

  resources :drive_sessions, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    member do
      post :complete
    end

    collection do
      get :export
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
