Rails.application.routes.draw do
  resources :quotes do
    member do
      patch :submit
      patch :approve
      patch :reject
      patch :accept
      patch :withdraw
    end
    
    collection do
      get :pending
      get :expiring_soon
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
    end
  end
  devise_for :users
  
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
