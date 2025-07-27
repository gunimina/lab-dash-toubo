# frozen_string_literal: true

module CrawlerConstants
  # 크롤러 상태 (Node.js와 동기화)
  CRAWLER_STATUS = {
    idle: 'idle',
    starting: 'starting',
    running: 'running',
    paused: 'paused',
    stopped: 'stopped',
    completed: 'completed',
    failed: 'failed'
  }.freeze
  
  # 상태 목록 (validation용)
  VALID_STATUSES = CRAWLER_STATUS.values.freeze
  
  # 크롤링 타입
  CRAWLING_TYPE = {
    initial: 'initial',
    daily: 'daily'
  }.freeze
  
  # 크롤링 단계 정의 (실제 소요 시간 기준)
  CRAWLING_STEPS = {
    1 => {
      number: 1,
      name: '카테고리 및 제품 수집',
      key: 'category_product_collection',
      weight: 85,  # 전체 작업의 85% (나머지가 2.5분 정도)
      sub_steps: {
        1 => '카테고리 목록 수집',
        2 => '부모/자식상품 수집',
        3 => 'iframe 스펙 크롤링'
      }
    },
    2 => {
      number: 2,
      name: 'AI 데이터 처리',
      key: 'ai_data_processing',
      weight: 10  # 전체 작업의 10% (평균 1-2분)
    },
    3 => {
      number: 3,
      name: '카탈로그 번호 생성',
      key: 'catalog_generation',
      weight: 2   # 전체 작업의 2% (30초)
    },
    4 => {
      number: 4,
      name: '데이터베이스 저장',
      key: 'database_setup',
      weight: 3   # 전체 작업의 3% (1분 이내)
    }
  }.freeze
  
  # API 엔드포인트
  API_ENDPOINTS = {
    health: '/api/health',
    status: '/api/status',
    crawl: '/api/crawl',
    pause: '/api/pause',
    resume: '/api/resume',
    stop: '/api/stop',
    reset: '/api/full-setup/reset',
    progress: '/api/progress',
    full_setup_progress: '/api/full-setup/progress'
  }.freeze
  
  # Webhook 타입
  WEBHOOK_TYPES = {
    log: 'log',
    progress: 'progress',
    status_change: 'status_change',
    error: 'error'
  }.freeze
  
  # 로그 레벨
  LOG_LEVELS = {
    info: 'info',
    warning: 'warning',
    error: 'error',
    success: 'success'
  }.freeze
  
  # 에러 메시지
  ERROR_MESSAGES = {
    crawler_already_running: 'Crawler is already running',
    crawler_not_running: 'Crawler is not running',
    invalid_crawler_type: 'Invalid crawler type',
    webhook_url_required: 'Webhook URL is required',
    crawler_not_paused: 'Crawler is not paused',
    reset_failed: 'Failed to reset crawler',
    api_connection_failed: 'Failed to connect to crawler API'
  }.freeze
  
  # 활성 상태 (실행 중인 상태들)
  ACTIVE_STATUSES = [
    CRAWLER_STATUS[:starting],
    CRAWLER_STATUS[:running],
    CRAWLER_STATUS[:paused]
  ].freeze
  
  # 종료 상태
  FINISHED_STATUSES = [
    CRAWLER_STATUS[:stopped],
    CRAWLER_STATUS[:completed],
    CRAWLER_STATUS[:failed]
  ].freeze
  
  # 재개 가능한 상태
  RESUMABLE_STATUSES = [
    CRAWLER_STATUS[:paused]
  ].freeze
  
  class << self
    def valid_status?(status)
      VALID_STATUSES.include?(status.to_s)
    end
    
    def active_status?(status)
      ACTIVE_STATUSES.include?(status.to_s)
    end
    
    def finished_status?(status)
      FINISHED_STATUSES.include?(status.to_s)
    end
    
    def resumable_status?(status)
      RESUMABLE_STATUSES.include?(status.to_s)
    end
    
    def step_name(step_number)
      CRAWLING_STEPS.dig(step_number, :name)
    end
    
    def all_step_names
      CRAWLING_STEPS.values.map { |step| step[:name] }
    end
    
    # 전체 진행률 계산 (가중치 반영)
    def calculate_overall_progress(step_number, step_progress)
      return 0 if step_number.nil? || step_progress.nil?
      
      # 이전 단계들의 가중치 합계
      previous_weight = (1...step_number).sum { |n| CRAWLING_STEPS.dig(n, :weight) || 0 }
      
      # 현재 단계의 가중치
      current_weight = CRAWLING_STEPS.dig(step_number, :weight) || 0
      
      # 현재 단계의 진행률을 가중치에 반영
      current_progress = (step_progress * current_weight / 100.0)
      
      # 전체 진행률
      (previous_weight + current_progress).round
    end
  end
end