class Admin::SyncCrawlingController < ApplicationController
  include CrawlerConstants
  
  def index
    @session = CrawlingSession.where(crawling_type: CRAWLING_TYPE[:initial])
                             .order(created_at: :desc)
                             .first
    @status = fetch_crawler_status
  end

  def start
    # 이미 실행 중인지 확인
    current_status = fetch_crawler_status
    if [CRAWLER_STATUS[:running], CRAWLER_STATUS[:paused]].include?(current_status[:status])
      redirect_to admin_sync_crawling_index_path, alert: "크롤링이 이미 진행 중입니다."
      return
    end

    # 세션 생성
    @session = CrawlingSession.create!(
      crawling_type: CRAWLING_TYPE[:initial],
      status: CRAWLER_STATUS[:starting],
      started_at: Time.current
    )

    # Node.js 크롤러 시작 (동기적으로 처리)
    result = CrawlerService.start_initial_crawl(
      session_id: @session.id,
      webhook_url: webhook_url
    )

    if result[:success]
      @session.update!(
        status: CRAWLER_STATUS[:running],
        job_id: result[:job_id]
      )
      
      # 크롤링이 시작되었으므로 페이지로 돌아감
      redirect_to admin_sync_crawling_index_path, notice: "크롤링이 시작되었습니다. 완료까지 약 4-5시간이 소요됩니다."
    else
      @session.destroy
      redirect_to admin_sync_crawling_index_path, alert: "크롤링 시작 실패: #{result[:error]}"
    end
  end

  def stop
    result = CrawlerService.stop
    
    # 세션 종료 처리
    @session = CrawlingSession.where(status: ['running', 'paused', 'starting']).last
    if @session
      @session.update!(
        status: CRAWLER_STATUS[:stopped],
        ended_at: Time.current
      )
    end
    
    # 진행 상황 삭제
    CrawlingProgress.destroy_all
    
    redirect_to admin_sync_crawling_index_path, notice: "크롤링이 중지되었습니다."
  end

  def reset
    # 실행 중인지 확인
    current_status = fetch_crawler_status
    if [CRAWLER_STATUS[:running], CRAWLER_STATUS[:paused]].include?(current_status[:status])
      redirect_to admin_sync_crawling_index_path, alert: "크롤링이 진행 중입니다. 먼저 중지해주세요."
      return
    end

    # 초기화 실행
    result = CrawlerService.reset
    
    if result[:success]
      CrawlingSession.destroy_all
      CrawlingProgress.destroy_all
      redirect_to admin_sync_crawling_index_path, notice: "초기화가 완료되었습니다."
    else
      redirect_to admin_sync_crawling_index_path, alert: "초기화 실패: #{result[:error]}"
    end
  end

  def refresh
    # 수동 새로고침을 위한 액션
    redirect_to admin_sync_crawling_index_path
  end

  private

  def fetch_crawler_status
    CrawlerService.get_status
  rescue => e
    Rails.logger.error "Crawler status error: #{e.message}"
    { status: 'disconnected', error: e.message }
  end

  def webhook_url
    "#{request.protocol}#{request.host_with_port}/admin/initial_crawling/webhook"
  end
end