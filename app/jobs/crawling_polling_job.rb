class CrawlingPollingJob < ApplicationJob
  include CrawlerConstants
  
  queue_as :default
  
  def perform(session_id)
    session = CrawlingSession.find(session_id)
    return if session.completed? || session.status == CRAWLER_STATUS[:stopped]
    
    # Node.js API에서 상태 가져오기
    status = CrawlerService.get_status
    
    # 상태가 변경되었을 때만 업데이트
    if session.status != status[:status]
      session.update!(status: status[:status])
    end
    
    # 진행률 업데이트가 있을 때 브로드캐스트
    if should_broadcast?(status)
      broadcast_status_update(session, status)
    end
    
    # 계속 폴링 (실행 중일 때만)
    if [CRAWLER_STATUS[:running], CRAWLER_STATUS[:paused]].include?(status[:status])
      CrawlingPollingJob.set(wait: 5.seconds).perform_later(session_id)
    elsif status[:status] == CRAWLER_STATUS[:completed]
      session.update!(status: CRAWLER_STATUS[:completed], ended_at: Time.current)
    end
  rescue => e
    Rails.logger.error "Polling error: #{e.message}"
    # 에러 시 재시도
    CrawlingPollingJob.set(wait: 10.seconds).perform_later(session_id)
  end
  
  private
  
  def should_broadcast?(status)
    # 항상 브로드캐스트 (또는 조건 추가 가능)
    true
  end
  
  def broadcast_status_update(session, status)
    # Turbo가 없는 환경에서는 브로드캐스트 스킵
    return unless defined?(Turbo::StreamsChannel)
    
    # 상태 카드 업데이트
    Turbo::StreamsChannel.broadcast_replace_to(
      "crawling_session_#{session.id}",
      target: "status-cards",
      partial: "admin/initial_crawling/status_cards",
      locals: { status: status }
    )
    
    # 진행률 업데이트
    current_progress = CrawlingProgress.where(step_number: status[:current_step]).first
    if current_progress
      Turbo::StreamsChannel.broadcast_replace_to(
        "crawling_session_#{session.id}",
        target: "progress-section",
        partial: "admin/initial_crawling/progress_section",
        locals: { 
          current_step: status[:current_step],
          progress: current_progress.current_progress || 0,
          step_name: step_name(status[:current_step])
        }
      )
    end
  end
  
  def step_name(step_number)
    case step_number
    when 1 then "카테고리 및 제품 수집"
    when 2 then "AI 데이터 처리"
    when 3 then "카탈로그 번호 생성"
    when 4 then "데이터베이스 저장"
    else "대기 중"
    end
  end
end