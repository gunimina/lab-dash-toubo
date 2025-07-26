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
    
    # 동기 크롤링 라우트
    get 'sync_crawling', to: 'sync_crawling#index', as: :sync_crawling_index
    
    scope 'sync_crawling' do
      post 'start', to: 'sync_crawling#start', as: :start_sync_crawling
      post 'stop', to: 'sync_crawling#stop', as: :stop_sync_crawling
      post 'reset', to: 'sync_crawling#reset', as: :reset_sync_crawling
      get 'refresh', to: 'sync_crawling#refresh', as: :refresh_sync_crawling
    end
    
    # 자료관리 라우트
    namespace :data_management do
      resources :products do
        collection do
          get 'search'
          post 'sync'
        end
      end
    end
  end

  # Root redirect to admin
  root to: redirect('/admin/initial_crawling')
end
