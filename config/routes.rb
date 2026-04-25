Rails.application.routes.draw do
  mount RailsIcons::Engine, at: "/rails_icons" if Rails.env.development?

  scope "(:locale)", locale: /ko|en/ do
    resources :houses do
      resources :checks, only: [ :create ], controller: :inspection_checks
      resource :summary, only: [ :show ]
    end
  end

  root to: redirect { |_, req|
    locale = LocaleResolver.call(
      param: nil,
      cookie: req.cookies["locale"],
      accept_language: req.env["HTTP_ACCEPT_LANGUAGE"]
    )
    "/#{locale}/houses"
  }

  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
