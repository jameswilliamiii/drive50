class PagesController < ApplicationController
  allow_unauthenticated_access only: :home
  layout "marketing"

  def home
  end
end
