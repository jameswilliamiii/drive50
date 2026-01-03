Rails.application.routes.draw do
  root "drive_sessions#index"

  resources :passwords, param: :token
  resource :session
  resources :registrations, only: [ :new, :create ]
  resource :user, only: [ :edit, :update ]

  resource :push_subscription, only: [ :new, :create, :destroy ]

  resources :drive_sessions, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    member do
      post :complete
    end

    collection do
      get :export
      get :all
    end
  end

  # PWA manifest and service worker (using Rails built-in controller)
  get "/manifest.json", to: "rails/pwa#manifest", as: :pwa_manifest
  get "/service-worker.js", to: "rails/pwa#service_worker", as: :pwa_service_worker

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
