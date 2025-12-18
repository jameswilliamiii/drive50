Rails.application.routes.draw do
  root "drive_sessions#index"

  resources :passwords, param: :token
  resource :session
  resources :registrations, only: [ :new, :create ]
  resource :user, only: [ :edit, :update ]

  resources :drive_sessions, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    member do
      post :complete
    end

    collection do
      get :export
      get :all
    end
  end

  # PWA manifest
  get "/manifest.json", to: "pwa#manifest", defaults: { format: :json }

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
