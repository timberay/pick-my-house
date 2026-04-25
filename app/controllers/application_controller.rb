class ApplicationController < ActionController::Base
  include OwnerIdentity
  include Localized

  allow_browser versions: :modern
end
