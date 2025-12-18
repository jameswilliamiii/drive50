class PwaController < ApplicationController
  # Manifest must be public so browsers can fetch it before login
  allow_unauthenticated_access only: :manifest

  def manifest
    # Always render JSON manifest for PWA detection
    render "pwa/manifest",
           formats: :json,
           content_type: "application/manifest+json"
  end
end
