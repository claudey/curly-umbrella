Rails.application.routes.draw do
  resources :documents do
    member do
      get :download
      patch :archive
      patch :restore
      get :versions
      post :new_version
      get :generate_pdf
    end

    collection do
      get :archived
      get :expiring
      get :search_suggestions
    end
  end
  # Customer portal routes
  namespace :customer do
    root 'dashboard#index'
    get 'dashboard', to: 'dashboard#index'
    
    resources :policies, only: [:index, :show] do
      member do
        post :renew
      end
    end
    
    resources :applications, only: [:index, :show, :new, :create]
    resources :claims, only: [:index, :show, :new, :create]
    resources :documents, only: [:index, :show]
    
    get 'profile', to: 'profile#show'
    patch 'profile', to: 'profile#update'
    get 'profile/edit', to: 'profile#edit'
    
    get 'support', to: 'support#index'
    post 'support', to: 'support#create'
    
    # API endpoints for portal
    get 'notifications', to: 'notifications#index'
    patch 'notifications/:id/mark_read', to: 'notifications#mark_read'
  end

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

    # Security Dashboard routes
    scope :security_dashboard, as: :security_dashboard do
      get "/", to: "security_dashboard#index", as: :index
      get "/alerts", to: "security_dashboard#alerts", as: :alerts
      get "/ip_blocks", to: "security_dashboard#ip_blocks", as: :ip_blocks
      get "/rate_limits", to: "security_dashboard#rate_limits", as: :rate_limits
      get "/audit_logs", to: "security_dashboard#audit_logs", as: :audit_logs
      get "/metrics_api", to: "security_dashboard#metrics_api", as: :metrics_api

      patch "/block_ip", to: "security_dashboard#block_ip", as: :block_ip
      patch "/unblock_ip", to: "security_dashboard#unblock_ip", as: :unblock_ip
      patch "/whitelist_ip", to: "security_dashboard#whitelist_ip", as: :whitelist_ip
      patch "/resolve_alert/:id", to: "security_dashboard#resolve_alert", as: :resolve_alert
      patch "/dismiss_alert/:id", to: "security_dashboard#dismiss_alert", as: :dismiss_alert
    end

    # Feature Flag Management routes
    resources :feature_flags do
      member do
        patch :toggle
      end

      collection do
        patch :bulk_toggle
        get :export
        post :import
        get :health
        post :clear_cache
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
  resources :notifications, only: [ :index, :show, :update ] do
    collection do
      get :unread_count
      patch :mark_all_as_read
    end
  end

  resource :notification_preferences, only: [ :show, :update ]
  # Client management routes
  resources :clients do
    member do
      patch :activate
      patch :deactivate
    end
    
    collection do
      get :search
    end
  end

  # Application routes for different insurance types
  resources :motor_applications do
    member do
      patch :submit_application
      patch :start_review
      patch :approve
      patch :reject
      get :print
    end
  end

  resources :life_applications do
    member do
      patch :submit_application
      patch :start_review
      patch :approve
      patch :reject
      get :print
    end
  end

  resources :fire_applications do
    member do
      patch :submit_application
      patch :start_review
      patch :approve
      patch :reject
      get :print
    end
  end

  resources :residential_applications do
    member do
      patch :submit_application
      patch :start_review
      patch :approve
      patch :reject
      get :print
    end
  end

  # Insurance companies management
  resources :insurance_companies_management, except: [:destroy], path: 'insurance_companies_admin', as: :insurance_companies_admin do
    member do
      patch :approve
      patch :reject
      patch :activate
      patch :deactivate
    end
    
    collection do
      get :pending
    end
  end

  # Settings routes
  namespace :settings do
    resource :organization, only: [:show, :edit, :update], controller: 'organizations'
    resources :users do
      member do
        patch :activate
        patch :deactivate
        patch :reset_password
      end
    end
    resource :preferences, only: [:show, :update]
  end
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    passwords: "users/passwords"
  }

  # Session management routes
  get "/sessions/manage", to: "users/sessions#manage_sessions", as: :manage_sessions
  delete "/sessions/terminate_others", to: "users/sessions#terminate_other_sessions", as: :terminate_other_sessions
  delete "/sessions/:session_id", to: "users/sessions#terminate_session", as: :terminate_session

  # Multi-factor authentication routes
  resource :mfa, only: [ :show ] do
    member do
      get :setup
      post :enable
      post :disable
      get :backup_codes
      post :regenerate_backup_codes
    end
  end

  resources :mfa_verifications, only: [ :new, :create ] do
    collection do
      get :backup_codes
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Favicon route to prevent 404 errors
  get "/favicon.ico", to: proc { [ 204, {}, [] ] }

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Audit logging routes
  resources :audits, only: [ :index, :show ] do
    collection do
      get :dashboard
      get :export
      get :compliance_report
    end
  end

  # Security monitoring routes
  scope :security, controller: :security do
    get :dashboard, as: :security_dashboard
    get :alerts, as: :security_alerts
    get "alerts/:id", action: :alert_details, as: :security_alert_details
    patch "alerts/:id/resolve", action: :resolve_alert, as: :resolve_security_alert
    patch "alerts/:id/dismiss", action: :dismiss_alert, as: :dismiss_security_alert
    patch "alerts/:id/investigate", action: :investigate_alert, as: :investigate_security_alert
    get :blocked_ips, as: :security_blocked_ips
    post :block_ip, as: :security_block_ip
    delete :unblock_ip, as: :security_unblock_ip
    get :threat_intelligence, as: :security_threat_intelligence
    get :settings, action: :security_settings, as: :security_settings
    patch :settings, action: :update_security_settings
    get :export_report, action: :export_security_report, as: :export_security_report
  end

  # Search routes
  resources :search, only: [ :index ] do
    collection do
      get :suggestions
      post :save
      get :history
      delete :clear_history, path: "history"
    end
  end

  # API routes
  namespace :api do
    namespace :v1 do
      # Search API routes
      scope :search do
        get :global, to: "search#global"
        get :suggestions, to: "search#suggestions"
        get :filters, to: "search#filters"
        get :history, to: "search#history"
        get :analytics, to: "search#analytics"
        delete :history, to: "search#clear_history"
      end
      resources :applications, except: [ :destroy ] do
        member do
          post :submit
          get :documents
          get :quotes
        end
      end

      resources :quotes, except: [ :destroy ] do
        member do
          post :accept
          post :generate_pdf
        end
      end

      resources :webhooks do
        member do
          post :test
          get :deliveries
        end
      end

      resources :analytics, only: [] do
        collection do
          get :usage
          get :dashboard
          get :performance
          get :export
          get :top_endpoints
          get :trends
        end
      end

      resources :feature_flags do
        member do
          post :toggle
        end

        collection do
          get :check
          get :health
          post :bulk_update
          get :export
          post :import
        end
      end
    end
  end

  # Executive Dashboard routes
  scope :executive, as: :executive_dashboard do
    get "/", to: "executive_dashboard#index", as: :index
    get "/analytics", to: "executive_dashboard#analytics", as: :analytics
    get "/trends", to: "executive_dashboard#trends", as: :trends
    get "/forecasting", to: "executive_dashboard#forecasting", as: :forecasting
    get "/performance", to: "executive_dashboard#performance", as: :performance
    get "/reports/:id", to: "executive_dashboard#reports", as: :report
    get "/live_metrics", to: "executive_dashboard#live_metrics", as: :live_metrics
    get "/export", to: "executive_dashboard#export_dashboard", as: :export

    post "/reports", to: "executive_dashboard#create_report", as: :create_report
    post "/reports/:id/generate", to: "executive_dashboard#generate_report", as: :generate_report
  end

  # API Documentation routes
  scope :developers, as: :developers do
    get "/", to: "api_docs#index", as: :api_docs
    get "/playground", to: "api_docs#playground", as: :api_playground
    post "/try", to: "api_docs#try_endpoint", as: :try_api_endpoint
    post "/code-example", to: "api_docs#generate_code_example", as: :generate_code_example
    get "/postman", to: "api_docs#download_postman_collection", as: :download_postman_collection
    get "/openapi", to: "api_docs#download_openapi_spec", as: :download_openapi_spec
  end

  # Root route
  root "home#index"
end
