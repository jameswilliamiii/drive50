Rails.application.routes.draw do
  # Signed-in visitors get their dashboard at "/"; everyone else sees the
  # marketing page. The constraint reads the same signed session cookie the
  # Authentication concern uses, so no nav links or post-auth redirects (which
  # all point at root_path/root_url) need to change. Any failure falls through
  # to the marketing page rather than erroring.
  authenticated = ->(request) do
    session_id = request.cookie_jar.signed[:session_id]
    session_id.present? && Session.exists?(session_id)
  rescue StandardError
    false
  end

  constraints(authenticated) do
    root "drive_sessions#index", as: :authenticated_root
  end

  root "pages#home"

  namespace :admin do
    resources :users
    resources :drive_sessions
    resources :sessions
    resources :push_subscriptions

    root to: "users#index"
  end

  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]
  resource :session, only: [ :new, :create, :destroy ]
  resources :registrations, only: [ :new, :create ]
  resource :user, only: [ :edit, :update ]

  get  "/onboarding/location", to: "onboarding#location", as: :onboarding_location
  post "/onboarding/location", to: "onboarding#save_location"
  get  "/onboarding/push",     to: "onboarding#push", as: :onboarding_push
  post "/onboarding/finish",   to: "onboarding#finish", as: :onboarding_finish

  # Timezone detection endpoint
  post :timezone, to: "timezones#update"

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
