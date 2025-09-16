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
      get '/', to: 'security_dashboard#index', as: :index
      get '/alerts', to: 'security_dashboard#alerts', as: :alerts
      get '/ip_blocks', to: 'security_dashboard#ip_blocks', as: :ip_blocks
      get '/rate_limits', to: 'security_dashboard#rate_limits', as: :rate_limits
      get '/audit_logs', to: 'security_dashboard#audit_logs', as: :audit_logs
      get '/metrics_api', to: 'security_dashboard#metrics_api', as: :metrics_api
      
      patch '/block_ip', to: 'security_dashboard#block_ip', as: :block_ip
      patch '/unblock_ip', to: 'security_dashboard#unblock_ip', as: :unblock_ip
      patch '/whitelist_ip', to: 'security_dashboard#whitelist_ip', as: :whitelist_ip
      patch '/resolve_alert/:id', to: 'security_dashboard#resolve_alert', as: :resolve_alert
      patch '/dismiss_alert/:id', to: 'security_dashboard#dismiss_alert', as: :dismiss_alert
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
  
  resource :notification_preferences, only: [:show, :update]
  resources :motor_applications do
    member do
      patch :submit_application
      patch :start_review
      patch :approve
      patch :reject
      get :print
    end
  end
  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }
  
  # Session management routes
  get '/sessions/manage', to: 'users/sessions#manage_sessions', as: :manage_sessions
  delete '/sessions/terminate_others', to: 'users/sessions#terminate_other_sessions', as: :terminate_other_sessions
  delete '/sessions/:session_id', to: 'users/sessions#terminate_session', as: :terminate_session
  
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

  # Audit logging routes
  resources :audits, only: [:index, :show] do
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
    get 'alerts/:id', action: :alert_details, as: :security_alert_details
    patch 'alerts/:id/resolve', action: :resolve_alert, as: :resolve_security_alert
    patch 'alerts/:id/dismiss', action: :dismiss_alert, as: :dismiss_security_alert
    patch 'alerts/:id/investigate', action: :investigate_alert, as: :investigate_security_alert
    get :blocked_ips, as: :security_blocked_ips
    post :block_ip, as: :security_block_ip
    delete :unblock_ip, as: :security_unblock_ip
    get :threat_intelligence, as: :security_threat_intelligence
    get :settings, action: :security_settings, as: :security_settings
    patch :settings, action: :update_security_settings
    get :export_report, action: :export_security_report, as: :export_security_report
  end
  
  # API routes
  mount BrokersyncApi => '/api'
  
  # API documentation route
  mount GrapeSwaggerRails::Engine => '/api/docs' if defined?(GrapeSwaggerRails)
  
  # Root route
  root "home#index"
end
