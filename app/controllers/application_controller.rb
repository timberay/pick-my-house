class ApplicationController < ActionController::Base
  include OwnerIdentity

  allow_browser versions: :modern
end
