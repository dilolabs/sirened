Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "unites_legales/:siren", to: "unites_legales#show"
      get "etablissements/:siret", to: "etablissements#show"
      resources :unites_legales, only: %i[index]
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Defines the root path route ("/")
  # root "posts#index"
end
