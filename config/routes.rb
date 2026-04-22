Rails.application.routes.draw do
  root "houses#index"

  resources :houses, only: [ :index, :new, :create, :show ] do
    resource  :report,  only: [ :show ], controller: "reports"
    resources :ratings, only: [ :update ]
    collection { get :compare, to: "reports#compare" }
  end

  # Spouse (rater) flow — share_token scoped
  scope "s/:share_token", as: :share do
    get  "/",                        to: "rater_sessions#show",    as: :session
    post "/",                        to: "rater_sessions#create"
    get  "/rate",                    to: "rater_sessions#rate",    as: :rate
    patch "/ratings/:category_id",   to: "ratings#rater_update",   as: :rating
  end

  # Health + PWA (Rails defaults)
  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
