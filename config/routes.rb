Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Admin namespace
  namespace :admin do
    # 단수형 컨트롤러를 사용하므로 명시적으로 경로 지정
    get 'initial_crawling', to: 'initial_crawling#index', as: :initial_crawling_index
    
    # 복수형 경로를 단수형으로 리다이렉트
    get 'initial_crawlings', to: redirect('/admin/initial_crawling')
    
    scope 'initial_crawling' do
      post 'start', to: 'initial_crawling#start', as: :start_initial_crawling
      post 'pause', to: 'initial_crawling#pause', as: :pause_initial_crawling
      post 'resume', to: 'initial_crawling#resume', as: :resume_initial_crawling
      post 'stop', to: 'initial_crawling#stop', as: :stop_initial_crawling
      post 'reset', to: 'initial_crawling#reset', as: :reset_initial_crawling
      post 'webhook', to: 'initial_crawling#webhook', as: :webhook_initial_crawling
      get ':id/status', to: 'initial_crawling#status', as: :initial_crawling_status
    end
    
  end

  # Root redirect to admin
  root to: redirect('/admin/initial_crawling')
end
