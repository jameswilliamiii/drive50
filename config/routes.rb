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

  resources :passwords, param: :token
  resource :session
  resources :registrations, only: [ :new, :create ]
  resource :user, only: [ :edit, :update ]

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
