Rails.application.routes.draw do
  # Root route
  root "home#index"
  
  # Authentication routes
  get "signup", to: "users#new"
  get "login", to: "sessions#new"
  post "signup", to: "users#create"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  
  # User routes
  resources :users, only: [:new, :create, :show]
  resources :sessions, only: [:new, :create, :destroy]
  
  # Main routes
  get "chat", to: "chat#index"
  resources :chat, only: [:index, :create]
  
  # Mount Action Cable
  mount ActionCable.server => '/cable'
  
  # API routes
  namespace :api do
    namespace :v1 do
      get "job_applications/create"
      get "job_applications/index"
      get "jobs/index"
      get "jobs/show"
      get "chat/create"
      get "chat/index"
    end
  end
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end