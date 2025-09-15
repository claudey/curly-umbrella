Rails.application.routes.draw do
  namespace :insurance_company do
    get "quotes/index"
    get "quotes/show"
    get "quotes/new"
    get "quotes/create"
    get "quotes/edit"
    get "quotes/update"
    get "applications/index"
    get "applications/show"
    get "dashboard/index"
  end
  namespace :admin do
    get "distributions/index"
    get "distributions/show"
    get "distributions/redistribute"
    get "distributions/expire"
    get "roles/index"
    get "roles/show"
    get "roles/new"
    get "roles/create"
    get "roles/edit"
    get "roles/update"
    get "roles/destroy"
    get "roles/assign_permissions"
    get "roles/revoke_permissions"
    
    resources :organizations do
      member do
        patch :activate
        patch :deactivate
      end
      
      collection do
        get :analytics
      end
    end
  end
  namespace :insurance_companies do
    root "portal#dashboard"
    get "dashboard", to: "portal#dashboard"
    get "applications", to: "portal#applications"
    get "applications/:id", to: "portal#show_application", as: :application
    get "quotes", to: "portal#quotes"
    get "quotes/new", to: "portal#new_quote"
    post "quotes", to: "portal#create_quote"
    get "quotes/:id", to: "portal#show_quote", as: :quote
    patch "quotes/:id", to: "portal#update_quote"
  end
  resources :quotes do
    member do
      patch :submit
      patch :approve
      patch :reject
      patch :accept
      patch :withdraw
      get :print
    end
    
    collection do
      get :pending
      get :expiring_soon
      get :compare
    end
  end
  resources :notifications, only: [:index, :show, :update] do
    collection do
      get :unread_count
      patch :mark_all_as_read
    end
  end
  resources :motor_applications do
    member do
      patch :submit_application
      patch :start_review
      patch :approve
      patch :reject
      get :print
    end
  end
  devise_for :users
  
  # Multi-factor authentication routes
  resource :mfa, only: [:show] do
    member do
      get :setup
      post :enable
      post :disable
      get :backup_codes
      post :regenerate_backup_codes
    end
  end
  
  resources :mfa_verifications, only: [:new, :create] do
    collection do
      get :backup_codes
    end
  end
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root route
  root "home#index"
end
