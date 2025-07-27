class Admin::InitialCrawlingController < ApplicationController
  include CrawlerConstants
  
  skip_before_action :verify_authenticity_token, only: [:webhook, :reset]
  before_action :set_turbo_frame_request_variant, only: [:start, :pause, :resume, :stop, :reset]
  
  def index
    # 오래된 실행 중인 세션 정리 (3일 이상 경과)
    old_running_sessions = CrawlingSession
      .where(status: ['running', 'paused', 'starting'])
      .where('created_at < ?', 3.days.ago)
    
    if old_running_sessions.exists?
      Rails.logger.info "[InitialCrawling#index] Cleaning up #{old_running_sessions.count} old running sessions"
      old_running_sessions.update_all(status: 'failed', ended_at: Time.current)
    end
    
    @status = fetch_crawler_status
    
    # 현재 실행 중인 세션이 있는지 확인
    if ['running', 'paused', 'starting'].include?(@status[:status])
      @session = CrawlingSession.where(status: ['running', 'paused', 'starting']).last
    else
      # 실행 중이 아니면 세션을 nil로 설정하여 초기 상태 표시
      @session = nil
    end
    
    @steps = build_steps_data
    
    # 크롤링 이력 (최근 5개)
    @crawling_history = CrawlingSession.includes(:crawling_progresses)
                                      .order(created_at: :desc)
                                      .limit(5)
    
    Rails.logger.info "[Index] Status: #{@status[:status]}, Session: #{@session&.id}, Steps: #{@steps.map { |s| "#{s[:number]}:#{s[:status]}" }.join(', ')}"
  end

  def start
    Rails.logger.info "[InitialCrawling#start] Starting crawler..."
    Rails.logger.info "[InitialCrawling#start] Request params: #{params.inspect}"
    Rails.logger.info "[InitialCrawling#start] Request headers: Accept=#{request.headers['Accept']}, X-Requested-With=#{request.headers['X-Requested-With']}"
    
    @session = CrawlingSession.create!(
      crawling_type: CRAWLING_TYPE[:initial],
      status: CRAWLER_STATUS[:starting],
      started_at: Time.current
    )
    
    Rails.logger.info "[InitialCrawling#start] Session created: #{@session.id}"
    Rails.logger.info "[InitialCrawling#start] Webhook URL: #{webhook_url}"
    Rails.logger.info "[InitialCrawling#start] Passing to CrawlerService - session_id: #{@session.id}, webhook_url: #{webhook_url}"
    
    # Node.js 크롤러 시작
    result = CrawlerService.start_initial_crawl(
      session_id: @session.id,
      webhook_url: webhook_url
    )
    
    Rails.logger.info "[InitialCrawling#start] CrawlerService result: #{result.inspect}"
    
    if result[:success]
      # 세션 상태 업데이트
      @session.update!(
        status: CRAWLER_STATUS[:running],
        job_id: result[:job_id]
      )
      
      # Turbo 요청인지 확인
      Rails.logger.info "[InitialCrawling#start] Accept header: #{request.headers["Accept"]}"
      Rails.logger.info "[InitialCrawling#start] Turbo-Frame header: #{request.headers["Turbo-Frame"]}"
      
      if request.headers["Accept"]&.include?("text/vnd.turbo-stream.html") || request.headers["Turbo-Frame"]
        Rails.logger.info "[InitialCrawling#start] Rendering Turbo Stream response"
        @status = { status: CRAWLER_STATUS[:running], current_step: 1, overall_progress: 0 }
        @steps = build_steps_data
        
        # 구독 정리를 위한 특별한 처리
        streams = []
        
        # 1. 먼저 기존 구독 제거
        if CrawlingSession.where(status: ['stopped', 'completed', 'failed']).exists?
          streams << turbo_stream.remove_all("turbo-cable-stream-source")
        end
        
        # 2. UI 업데이트
        streams << turbo_stream.replace("status-section", 
          partial: "admin/initial_crawling/status_section", 
          locals: { status: CRAWLER_STATUS[:running] })
          
        streams << turbo_stream.replace("control-buttons",
          partial: "admin/initial_crawling/control_buttons",
          locals: { status: CRAWLER_STATUS[:running] })
        
        streams << turbo_stream.replace("step-indicator",
          partial: "admin/initial_crawling/step_indicator",
          locals: { steps: @steps, current_step: 1 })
          
        # 3. 새 구독 추가 (마지막에)
        streams << turbo_stream.append("body",
          "<turbo-cable-stream-source 
            id='crawling-stream-#{@session.id}'
            channel='Turbo::StreamsChannel' 
            signed-stream-name='#{Turbo::StreamsChannel.signed_stream_name("crawling_session_#{@session.id}")}'>
          </turbo-cable-stream-source>")
          
        streams << turbo_stream.append("notifications",
          partial: "shared/alert",
          locals: { message: "크롤링이 시작되었습니다.", type: :success })
        
        render turbo_stream: streams
      else
        redirect_to admin_initial_crawling_index_path, notice: "크롤링이 시작되었습니다."
      end
    else
      @session.destroy
      if request.headers["Accept"]&.include?("text/vnd.turbo-stream.html") || request.headers["Turbo-Frame"]
        render turbo_stream: turbo_stream.append("notifications",
          partial: "shared/alert",
          locals: { message: "크롤링 시작 실패: #{result[:error]}", type: :error }), layout: false
      else
        redirect_to admin_initial_crawling_index_path, alert: "크롤링 시작 실패: #{result[:error]}"
      end
    end
  end

  def pause
    Rails.logger.info "[InitialCrawling#pause] Pausing crawler..."
    Rails.logger.info "[InitialCrawling#pause] Request format: #{request.format}"
    
    result = CrawlerService.pause
    update_session_status(CRAWLER_STATUS[:paused]) if result[:success]
    
    Rails.logger.info "[InitialCrawling#pause] Result: #{result.inspect}"
    
    # 무조건 Turbo Stream으로 응답
    @session = CrawlingSession.where(status: ['running', 'paused', 'stopped']).last
    @status = fetch_crawler_status
    @steps = build_steps_data
    
    Rails.logger.info "[InitialCrawling#pause] Forcing Turbo Stream response"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("status-section",
            partial: "admin/initial_crawling/status_section",
            locals: { status: @status[:status] }),
          turbo_stream.replace("control-buttons",
            partial: "admin/initial_crawling/control_buttons",
            locals: { status: @status[:status] }),
          turbo_stream.replace("step-indicator",
            partial: "admin/initial_crawling/step_indicator",
            locals: { steps: @steps, current_step: @status[:current_step] || 0 })
        ], layout: false
      end
      format.html { redirect_to admin_initial_crawling_index_path }
    end
  end

  def resume
    Rails.logger.info "[InitialCrawling#resume] Resuming crawler..."
    Rails.logger.info "[InitialCrawling#resume] Request format: #{request.format}"
    
    result = CrawlerService.resume
    update_session_status(CRAWLER_STATUS[:running]) if result[:success]
    
    Rails.logger.info "[InitialCrawling#resume] Result: #{result.inspect}"
    
    # 무조건 Turbo Stream으로 응답
    @session = CrawlingSession.where(status: ['running', 'paused', 'stopped']).last
    @status = fetch_crawler_status
    @steps = build_steps_data
    
    Rails.logger.info "[InitialCrawling#resume] Forcing Turbo Stream response"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("status-section",
            partial: "admin/initial_crawling/status_section",
            locals: { status: @status[:status] }),
          turbo_stream.replace("control-buttons",
            partial: "admin/initial_crawling/control_buttons",
            locals: { status: @status[:status] }),
          turbo_stream.replace("step-indicator",
            partial: "admin/initial_crawling/step_indicator",
            locals: { steps: @steps, current_step: @status[:current_step] || 0 })
        ], layout: false
      end
      format.html { redirect_to admin_initial_crawling_index_path }
    end
  end

  def stop
    Rails.logger.info "[InitialCrawling#stop] Stopping crawler..."
    Rails.logger.info "[InitialCrawling#stop] Request format: #{request.format}"
    Rails.logger.info "[InitialCrawling#stop] Accept header: #{request.headers['Accept']}"
    
    result = CrawlerService.stop
    
    # 성공 여부와 관계없이 상태 업데이트
    update_session_status(CRAWLER_STATUS[:stopped])
    @session = CrawlingSession.where(status: ['running', 'paused', 'stopped']).last
    @session&.update!(ended_at: Time.current)
    
    Rails.logger.info "[InitialCrawling#stop] Result: #{result.inspect}"
    
    # 중지 시 진행 상태를 모두 종료로 변경
    CrawlingProgress.destroy_all
    
    # 무조건 Turbo Stream으로 응답
    @status = { status: CRAWLER_STATUS[:stopped] }  # 명시적으로 stopped 상태 설정
    @steps = build_steps_data
    
    Rails.logger.info "[InitialCrawling#stop] Forcing Turbo Stream response"
    
    # 명시적으로 format과 layout 설정
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          # 1. Turbo Stream 구독 제거
          turbo_stream.remove_all("turbo-cable-stream-source"),
          
          # 2. 상태 섹션 업데이트 (data-crawling-status 포함)
          turbo_stream.replace("status-section",
            partial: "admin/initial_crawling/status_section", 
            locals: { status: CRAWLER_STATUS[:stopped] }),
            
          # 3. 버튼 영역만 업데이트
          turbo_stream.replace("control-buttons",
            partial: "admin/initial_crawling/control_buttons",
            locals: { status: CRAWLER_STATUS[:stopped] }),
            
          # 4. 단계 표시기 업데이트
          turbo_stream.replace("step-indicator",
            partial: "admin/initial_crawling/step_indicator",
            locals: { steps: @steps, current_step: 0 })
        ], layout: false
      end
      format.html { redirect_to admin_initial_crawling_index_path }
    end
  end

  def reset
    Rails.logger.info "[InitialCrawling#reset] Resetting crawler..."
    
    # 현재 상태 재확인
    current_status = fetch_crawler_status
    if [CRAWLER_STATUS[:running], CRAWLER_STATUS[:paused]].include?(current_status[:status])
      Rails.logger.warn "[InitialCrawling#reset] 크롤링 진행 중 초기화 시도 차단"
      
      if request.headers["Accept"]&.include?("text/vnd.turbo-stream.html") || request.headers["Turbo-Frame"]
        render turbo_stream: turbo_stream.append("notifications",
          partial: "shared/alert",
          locals: { message: "크롤링이 진행 중입니다. 먼저 중지해주세요.", type: :error }), layout: false
        return
      else
        redirect_to admin_initial_crawling_index_path, alert: "크롤링이 진행 중입니다. 먼저 중지해주세요."
        return
      end
    end
    
    result = CrawlerService.reset
    
    if result[:success]
      # 세션과 연관된 진행 상황도 함께 삭제 (dependent: :destroy)
      CrawlingSession.destroy_all
      CrawlingProgress.destroy_all  # 진행률도 모두 삭제
      
      Rails.logger.info "[InitialCrawling#reset] All crawling sessions and progress data deleted"
    end
    
    Rails.logger.info "[InitialCrawling#reset] Result: #{result.inspect}"
    
    if request.headers["Accept"]&.include?("text/vnd.turbo-stream.html") || request.headers["Turbo-Frame"]
      # 초기 상태 데이터 준비
      @status = { status: CRAWLER_STATUS[:idle], current_step: 0, overall_progress: 0 }
      @steps = build_steps_data
      
      # 크롤링 이력도 다시 로드 (빈 상태)
      @crawling_history = CrawlingSession.none
      
      render turbo_stream: [
        turbo_stream.replace("status-section", 
          partial: "admin/initial_crawling/status_section", 
          locals: { status: CRAWLER_STATUS[:idle] }),
        turbo_stream.replace("control-buttons",
          partial: "admin/initial_crawling/control_buttons",
          locals: { status: CRAWLER_STATUS[:idle] }),
        turbo_stream.replace("step-indicator",
          partial: "admin/initial_crawling/step_indicator",
          locals: { steps: @steps, current_step: 0 }),
        turbo_stream.replace("crawling-history",
          partial: "admin/initial_crawling/crawling_history",
          locals: { crawling_history: @crawling_history }),
        turbo_stream.append("notifications",
          partial: "shared/alert",
          locals: { message: "초기화가 완료되었습니다. 모든 크롤링 데이터가 삭제되었습니다.", type: :success })
      ]
    else
      redirect_to admin_initial_crawling_index_path, notice: "초기화가 완료되었습니다."
    end
  end

  def status
    # 폴링 비활성화 - 이 액션은 더 이상 사용되지 않음
    # 모든 상태 업데이트는 webhook을 통해 처리됨
    Rails.logger.warn "[Status] Ajax polling attempt detected - this should not happen with webhook-only approach"
    
    # 혹시 모를 요청에 대비해 빈 응답 반환
    render json: { message: "Polling disabled. Updates via webhook only." }, status: :ok
  end

  def webhook
    Rails.logger.info "[Webhook] Received params: #{params.inspect}"
    Rails.logger.info "[Webhook] Progress: #{params[:progress]}, Phase: #{params[:phase]}, Message: #{params[:message]}"
    
    # 로그 타입의 webhook은 무시 (의미없는 webhook 필터링)
    if params[:type] == 'log' && params[:session_id].blank?
      Rails.logger.info "[Webhook] Ignoring log-type webhook without session_id"
      render json: { success: true, ignored: true }
      return
    end
    
    # 세션 찾기
    session_id = params[:session_id] || params[:sessionId]
    Rails.logger.info "[Webhook] Looking for session ID: #{session_id}"
    
    # 세션 ID가 있으면 찾고, 없으면 현재 실행 중인 세션 찾기
    if session_id.present?
      @session = CrawlingSession.find_by(id: session_id)
    else
      # 실행 중인 세션 찾기 (completed 상태도 포함)
      @session = CrawlingSession.where(status: ['running', 'paused', 'starting']).last
      
      # 완료 메시지인 경우 가장 최근 세션 찾기
      if @session.nil? && params[:message]&.include?("모든 초기 설정이 완료되었습니다")
        @session = CrawlingSession.order(created_at: :desc).first
        Rails.logger.info "[Webhook] No running session, using most recent session for completion: #{@session&.id}"
      end
      
      Rails.logger.info "[Webhook] No session ID provided, found session: #{@session&.id}"
    end
    
    # 세션이 없으면 에러 반환 (완료 메시지가 아닌 경우만)
    unless @session
      if params[:message]&.include?("모든 초기 설정이 완료되었습니다")
        Rails.logger.warn "[Webhook] No session found for completion message, ignoring"
        render json: { success: true, ignored: true }
        return
      end
      
      Rails.logger.error "[Webhook] Session not found for ID: #{session_id}"
      Rails.logger.error "[Webhook] All params: #{params.to_unsafe_h}"
      render json: { error: 'Session not found', session_id: session_id }, status: :unprocessable_entity
      return
    end
    
    # 진행상황 업데이트 처리
    step = extract_step_from_params
    message = params[:message] || ""
    phase = params[:phase] # Node.js에서 전달한 phase 정보
    
    # Node.js에서 전달한 실제 진행률 사용
    progress = extract_progress_from_params
    
    # Step 1의 경우 Node.js에서 전달한 진행률 그대로 사용
    if step == 1
      Rails.logger.info "[Webhook] Step 1 - Original Progress: #{progress}%, Message: #{message}"
      
      # 내부 단계 계산 (25% 단위)
      internal_step = if progress <= 25
        1  # 카테고리
      elsif progress <= 50
        2  # 부모상품
      elsif progress <= 75
        3  # 자식상품
      else
        4  # 상세정보
      end
      
      Rails.logger.info "[Webhook] Step 1 - Progress: #{progress}%, Internal Step: #{internal_step}"
    end
    
    # Phase 정보가 있으면 메시지에 포함
    if phase.present? && step == 1
      message = "Step 1: #{phase}"
      Rails.logger.info "[Webhook] Step 1 Phase update - phase: #{phase}, message: #{message}"
    end
    
    # sub_step 파라미터 직접 처리
    sub_step = params[:sub_step]
    if sub_step.present? && step == 1
      Rails.logger.info "[Webhook] Step 1 Sub-step update - sub_step: #{sub_step}, message: #{message}"
      Rails.logger.info "[Webhook] Full params: #{params.inspect}"
    end
    
    # Step 4 완료 메시지 확인 (더 넓은 패턴 매칭)
    if step == 4 && (message.include?("완료") || message.include?("SQLite") || message.include?("SUCCESS"))
      Rails.logger.info "[Webhook] Step 4 완료 감지! Original progress: #{progress}%, Message: #{message}"
      progress = 100 # Step 4 완료시 100%로 설정
      Rails.logger.info "[Webhook] Progress set to 100% for Step 4 completion"
    end
    
    if step
      update_progress(step, progress, message, sub_step)
      
      # current_step 정보 업데이트
      @status = fetch_crawler_status
      @status[:current_step] = step
      
      # 즉시 Turbo Streams 브로드캐스트
      broadcast_all_updates
    end
    
    # 상태 변경 처리
    if params[:type] == 'status_change' && @session
      new_status = params[:status] || params[:newStatus]
      if new_status
        @session.update!(status: new_status)
        
        # completed 상태면 종료 시간 기록
        if new_status == CRAWLER_STATUS[:completed]
          @session.update!(ended_at: Time.current)
          Rails.logger.info "[Webhook] 크롤링 완료, 세션 종료"
        end
      end
      broadcast_all_updates
    end
    
    # 모든 초기 설정 완료 메시지 확인
    if message.include?("모든 초기 설정이 완료되었습니다")
      Rails.logger.info "[Webhook] 전체 크롤링 완료 감지!"
      @session.update!(
        status: CRAWLER_STATUS[:completed],
        ended_at: Time.current
      )
      
      # 모든 단계를 완료로 표시
      (1..4).each do |step_num|
        progress = CrawlingProgress.find_or_create_by(
          crawling_session: @session,
          step_number: step_num
        )
        progress.update!(
          current_progress: 100,
          status: 'completed'
        )
      end
      
      # 완료 후 초기 상태로 UI 업데이트
      Rails.logger.info "[Webhook] Calling broadcast_completion_updates..."
      broadcast_completion_updates
      Rails.logger.info "[Webhook] broadcast_completion_updates completed"
    end
    
    render json: { success: true }
  end

  private


  def fetch_crawler_status
    CrawlerService.get_status
  rescue => e
    Rails.logger.error "Crawler status error: #{e.message}"
    { status: 'disconnected', error: e.message }
  end

  def build_steps_data
    # 현재 크롤러 상태 가져오기
    current_status = @status || fetch_crawler_status
    current_step_number = current_status[:current_step] || 0
    
    Rails.logger.info "[BuildSteps] Current status: #{current_status.inspect}"
    Rails.logger.info "[BuildSteps] Current step number: #{current_step_number}"
    Rails.logger.info "[BuildSteps] Session: #{@session&.id}"
    
    # 크롤러가 실행 중인지 확인
    is_running = ['running', 'paused'].include?(current_status[:status])
    
    steps = CRAWLING_STEPS.map do |number, step_info|
      { 
        number: step_info[:number], 
        name: step_info[:name], 
        status: 'waiting',
        sub_steps: step_info[:sub_steps],
        sub_step: nil,
        progress: 0
      }
    end
    
    # DB에서 진행상황 반영 (현재 세션만)
    progresses = @session ? CrawlingProgress.where(crawling_session: @session) : []
    progresses.each do |progress|
      step = steps[progress.step_number - 1]
      next unless step
      
      Rails.logger.info "[BuildSteps] Processing CrawlingProgress: Step #{progress.step_number}, Progress: #{progress.current_progress}%, Status: #{progress.status}"
      
      step[:progress] = progress.current_progress || 0
      step[:status] = if (progress.current_progress || 0) >= 100
                       'completed'
                     elsif (progress.current_progress || 0) > 0
                       'running'
                     else
                       'waiting'
                     end
                     
      # Step 1의 경우 진행 중이면 내부 단계도 감지
      if progress.step_number == 1 && step[:status] == 'running'
        # 먼저 메시지로 감지 시도
        current_sub_step = detect_sub_step_from_message(progress.message)
        Rails.logger.info "[BuildSteps] Step 1 - Message detection result: #{current_sub_step}"
        
        # 메시지로 감지 못하면 진행률로 추정
        if current_sub_step.nil?
          current_sub_step = detect_sub_step_from_progress(progress)
          Rails.logger.info "[BuildSteps] Step 1 - Progress detection result: #{current_sub_step}"
        end
        
        step[:sub_step] = current_sub_step
        Rails.logger.info "[BuildSteps] Step 1 - Final sub_step: #{current_sub_step}, Progress: #{progress.current_progress}%, Message: #{progress.message}"
      end
    end
    
    # 현재 실제로 진행 중인 단계 찾기
    actual_running_step = nil
    steps.each_with_index do |step, index|
      if step[:status] == 'running' && step[:progress] < 100
        actual_running_step = index + 1
        break
      end
    end
    
    # 만약 running 상태인 단계가 없다면 가장 높은 completed 다음 단계
    if !actual_running_step && is_running
      last_completed = 0
      steps.each_with_index do |step, index|
        if step[:status] == 'completed'
          last_completed = index + 1
        end
      end
      actual_running_step = last_completed < 4 ? last_completed + 1 : 4
      
      # 해당 단계를 running으로 설정
      if steps[actual_running_step - 1]
        steps[actual_running_step - 1][:status] = 'running'
      end
    end
    
    # current_step_number 업데이트
    current_step_number = actual_running_step || current_step_number
    
    Rails.logger.info "[BuildSteps] Actual running step: #{actual_running_step}"
    
    Rails.logger.info "[BuildSteps] Final steps data: #{steps.inspect}"
    
    steps
  end
  
  def detect_sub_step_from_message(message)
    return nil if message.blank?
    
    Rails.logger.info "[DetectSubStep] Checking message: #{message}"
    
    # 내부X단계 형식을 먼저 체크
    if message.match?(/내부(\d)단계/)
      sub_step = message.match(/내부(\d)단계/)[1].to_i
      Rails.logger.info "[DetectSubStep] Detected from 내부X단계 format: #{sub_step}"
      return sub_step
    end
    
    sub_step = if message.match?(/카테고리|category|분류/i)
      1
    elsif message.match?(/부모상품 수집|부모|parent|자식|child|PHASE 1|기본.*데이터.*수집/i)
      2
    elsif message.match?(/iframe|스펙|spec|PHASE 2/i)
      3
    else
      nil
    end
    
    Rails.logger.info "[DetectSubStep] Detected sub_step: #{sub_step}"
    sub_step
  end
  
  def detect_sub_step_from_progress(progress)
    return nil unless progress
    
    # 진행률 기반 추정 (3단계)
    current = progress.current_progress || 0
    if current <= 33
      1  # 카테고리 수집
    elsif current <= 66
      2  # 부모/자식상품 수집
    else
      3  # iframe 스펙 크롤링
    end
  end
  
  def detect_sub_step_from_session
    # 세션의 최근 진행 메시지로부터 내부 단계 감지
    last_progress = CrawlingProgress.where(step_number: 1).last
    Rails.logger.info "[SubStep] Last progress: #{last_progress&.inspect}"
    return nil unless last_progress
    
    message = last_progress.message || ""
    Rails.logger.info "[SubStep] Message: #{message}"
    
    sub_step = if message.include?("카테고리") || message.include?("=== 1단계")
      1
    elsif message.include?("부모상품 수집") || message.include?("=== 2단계")
      2
    elsif message.include?("PHASE") || message.include?("상세 정보") || message.include?("=== 3단계")
      3
    else
      nil
    end
    
    Rails.logger.info "[SubStep] Detected sub_step: #{sub_step}"
    sub_step
  end

  def update_session_status(status)
    @session = CrawlingSession.where(status: ['running', 'paused']).last
    @session&.update!(status: status)
  end

  def render_control_update
    @session = CrawlingSession.where(status: ['running', 'paused', 'stopped']).last
    @status = fetch_crawler_status
    
    Rails.logger.info "[render_control_update] Session: #{@session&.status}, Status: #{@status[:status]}"
    Rails.logger.info "[render_control_update] Rendering Turbo Stream replace for control-panel"
    
    render turbo_stream: [
      turbo_stream.replace("status-section",
        partial: "admin/initial_crawling/status_section",
        locals: { status: @status[:status] }),
      turbo_stream.replace("control-buttons",
        partial: "admin/initial_crawling/control_buttons",
        locals: { status: @status[:status] })
    ], layout: false
  end

  def webhook_url
    "#{request.protocol}#{request.host_with_port}/admin/initial_crawling/webhook"
  end

  def extract_step_from_params
    # 메시지에서 단계 추출 로직
    message = params[:message] || ""
    
    # 명시적인 step 파라미터가 있으면 우선 사용
    if params[:step]
      return params[:step].to_i
    end
    
    # Step 4 (가장 구체적인 것부터 체크)
    if message.include?("Step 4") || message.include?("데이터베이스") || 
       message.include?("SQLite") || message.include?("DB 구축")
      4
    # Step 3
    elsif message.include?("Step 3") || message.include?("카탈로그")
      3
    # Step 2
    elsif message.include?("Step 2") || message.include?("AI")
      2
    # Step 1의 내부 단계들
    elsif message.include?("Step 0-1") || message.include?("Step 1") || 
          message.include?("카테고리") || message.include?("부모상품") || 
          message.include?("자식상품") || message.include?("PHASE")
      1
    else
      # 구분선이나 빈 메시지는 현재 단계 유지
      if message.match?(/^=+$/) || message.strip.empty?
        # 현재 진행 중인 단계 찾기
        current_progress = CrawlingProgress.where(crawling_session: @session, status: 'running')
                                         .order(step_number: :desc).first
        current_progress&.step_number || 1
      else
        1  # 기본값
      end
    end
  end

  def extract_progress_from_params
    # Node.js에서 전달하는 실제 진행률 사용
    # 예: { progress: 60, processed: 600, total: 1000 }
    if params[:processed] && params[:total] && params[:total].to_i > 0
      # 실제 처리된 파일 수 기반 계산
      ((params[:processed].to_f / params[:total].to_f) * 100).round
    elsif params[:progress]
      # 기본 progress 값 사용
      params[:progress].to_i
    else
      # 메시지에서 제품 번호로 진행률 추정
      message = params[:message] || ""
      step = extract_step_from_params
      
      if step == 1
        # Step 1의 내부 단계별 진행률 계산
        if message.match?(/카테고리|category|분류|=== 1단계/i)
          # 카테고리 단계 (0-25%)
          if match = message.match(/\((\d+)\)/)
            category_num = match[1].to_i
            # 카테고리는 대략 100개 정도
            [(category_num / 4.0).round, 25].min
          else
            5  # 시작 진행률
          end
        elsif message.match?(/부모|parent|상위.*제품|=== 2단계/i)
          # 부모상품 단계 (25-50%)
          if match = message.match(/\((\d+)\)/)
            parent_num = match[1].to_i
            # 부모상품은 대략 2000개
            25 + [(parent_num / 80.0).round, 25].min
          else
            30  # 시작 진행률
          end
        elsif message.match?(/자식|child|하위.*제품|PHASE 1|기본.*크롤링/i)
          # 자식상품 단계 (50-75%)
          if match = message.match(/\((\d+)\)/)
            child_num = match[1].to_i
            # 자식상품은 대략 18000개
            50 + [(child_num / 720.0).round, 25].min
          else
            55  # 시작 진행률
          end
        elsif message.match?(/iframe|스펙|spec|PHASE 2/i)
          # 상세정보 단계 (75-100%)
          if match = message.match(/\((\d+)\)/)
            detail_num = match[1].to_i
            # 상세정보도 대략 18000개
            75 + [(detail_num / 720.0).round, 25].min
          else
            80  # 시작 진행률
          end
        else
          # 기본 패턴 매칭
          if match = message.match(/\((\d+)\)/)
            product_number = match[1].to_i
            # 전체 약 20000개 기준
            [(product_number / 200.0).round, 100].min
          else
            0
          end
        end
      else
        # 다른 단계는 메시지나 기본값 사용
        0
      end
    end
  end

  def update_progress(step, progress, message, sub_step = nil)
    return unless @session
    
    crawling_progress = CrawlingProgress.find_or_create_by(
      crawling_session: @session,
      step_number: step
    )
    
    # sub_step이 전달된 경우 메시지에 명확하게 포함
    if sub_step.present? && step == 1
      message = "내부#{sub_step}단계: #{message.split(': ').last}"
      Rails.logger.info "[UpdateProgress] Setting sub_step #{sub_step} in message"
    end
    
    crawling_progress.update!(
      current_progress: progress,
      message: message,
      status: progress >= 100 ? 'completed' : 'running'
    )
    
    Rails.logger.info "[UpdateProgress] Step #{step}, Progress: #{progress}%, Sub-step: #{sub_step}, Message: #{message}"
    
    # 이전 단계들을 모두 완료 처리
    if step > 1
      (1...step).each do |prev_step|
        prev_progress = CrawlingProgress.find_or_create_by(
          crawling_session: @session,
          step_number: prev_step
        )
        if prev_progress.current_progress < 100
          prev_progress.update!(
            current_progress: 100,
            status: 'completed'
          )
        end
      end
    end
    
    # Step 4가 100% 완료되면 세션 종료
    if step == 4 && progress >= 100
      Rails.logger.info "[UpdateProgress] Step 4 100% 완료 감지! 크롤링 완료 처리 시작..."
      
      @session.update!(
        status: CRAWLER_STATUS[:completed],
        ended_at: Time.current
      )
      Rails.logger.info "[UpdateProgress] 세션 상태를 completed로 변경 완료"
      
      # 모든 단계를 완료로 표시
      (1..4).each do |step_num|
        p = CrawlingProgress.find_or_create_by(
          crawling_session: @session,
          step_number: step_num
        )
        p.update!(
          current_progress: 100,
          status: 'completed'
        )
      end
      Rails.logger.info "[UpdateProgress] 모든 단계 완료 처리 완료"
      
      # Rails 8 방식: Turbo Streams로 완료 처리
      broadcast_completion_updates
    end
  end

  def broadcast_progress_update
    return unless @session
    
    Turbo::StreamsChannel.broadcast_replace_to(
      "crawling_session_#{@session.id}",
      target: "step-indicator",
      partial: "admin/initial_crawling/step_indicator",
      locals: { steps: build_steps_data }
    )
  end
  
  def broadcast_all_updates
    return unless @session
    
    Rails.logger.info "[Broadcast] Starting broadcast_all_updates for session #{@session.id}"
    
    @status = fetch_crawler_status
    steps = build_steps_data
    current_step = @status[:current_step] || 1
    
    Rails.logger.info "[Broadcast] Broadcasting to channel: crawling_session_#{@session.id}"
    step1_data = steps.find { |s| s[:number] == 1 }
    Rails.logger.info "[Broadcast] Current step 1 data: #{step1_data&.inspect}"
    Rails.logger.info "[Broadcast] Step 1 progress: #{step1_data&.dig(:progress)}%"
    Rails.logger.info "[Broadcast] Step 1 sub_step: #{step1_data&.dig(:sub_step)}"
    Rails.logger.info "[Broadcast] Step 1 status: #{step1_data&.dig(:status)}"
    
    begin
      # 개별 브로드캐스트를 하나씩 로그로 확인
      Rails.logger.info "[Broadcast] Replacing step-indicator..."
      
      Turbo::StreamsChannel.broadcast_replace_to(
        "crawling_session_#{@session.id}",
        target: "step-indicator",
        partial: "admin/initial_crawling/step_indicator",
        locals: { steps: steps, current_step: current_step }
      )
      Rails.logger.info "[Broadcast] step-indicator replaced"
      
      Rails.logger.info "[Broadcast] Replacing status-section..."
      Turbo::StreamsChannel.broadcast_replace_to(
        "crawling_session_#{@session.id}",
        target: "status-section",
        partial: "admin/initial_crawling/status_section",
        locals: { status: @status[:status] }
      )
      Rails.logger.info "[Broadcast] status-section replaced"
      
      Rails.logger.info "[Broadcast] Replacing control-buttons..."
      Turbo::StreamsChannel.broadcast_replace_to(
        "crawling_session_#{@session.id}",
        target: "control-buttons",
        partial: "admin/initial_crawling/control_buttons",
        locals: { status: @status[:status] }
      )
      Rails.logger.info "[Broadcast] control-buttons replaced"
      
      # 업데이트 타임스탬프 전송
      Turbo::StreamsChannel.broadcast_append_to(
        "crawling_session_#{@session.id}",
        target: "body",
        html: "<div data-turbo-temporary style='display:none' data-action='connection-monitor#markUpdate'></div>"
      )
      
      Rails.logger.info "[Broadcast] Broadcast completed successfully"
    rescue => e
      Rails.logger.error "[Broadcast] Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  def broadcast_completion_updates
    return unless @session
    
    Rails.logger.info "[Broadcast] Broadcasting completion updates for session #{@session.id}"
    
    # 초기 상태 데이터 준비
    initial_steps = build_initial_steps_data
    
    # 완료된 세션의 진행 데이터 삭제 (깨끗한 초기 상태로)
    CrawlingProgress.where(crawling_session: @session).destroy_all
    Rails.logger.info "[Broadcast] Cleaned up CrawlingProgress data for completed session"
    
    begin
      # Rails 8 방식: Turbo Streams로 UI 업데이트
      
      # 1. 완료 알림 표시
      Turbo::StreamsChannel.broadcast_append_to(
        "crawling_session_#{@session.id}",
        target: "notifications",
        partial: "shared/alert",
        locals: { 
          message: "크롤링이 완료되었습니다.", 
          type: :success
        }
      )
      
      # 2. 모든 단계를 초기 상태로 리셋
      Turbo::StreamsChannel.broadcast_replace_to(
        "crawling_session_#{@session.id}",
        target: "step-indicator",
        partial: "admin/initial_crawling/step_indicator",
        locals: { steps: initial_steps, current_step: 0 }
      )
      
      # 3. 상태 섹션을 idle로 변경 (이것이 Ajax Polling을 자동으로 중지시킴)
      Turbo::StreamsChannel.broadcast_replace_to(
        "crawling_session_#{@session.id}",
        target: "status-section",
        partial: "admin/initial_crawling/status_section",
        locals: { status: CRAWLER_STATUS[:idle] }
      )
      
      # 4. 컨트롤 버튼을 초기 상태로
      Turbo::StreamsChannel.broadcast_replace_to(
        "crawling_session_#{@session.id}",
        target: "control-buttons",
        partial: "admin/initial_crawling/control_buttons",
        locals: { status: CRAWLER_STATUS[:idle] }
      )
      
      # 5. Turbo Streams 구독 제거
      Turbo::StreamsChannel.broadcast_remove_to(
        "crawling_session_#{@session.id}",
        targets: "#crawling-stream-#{@session.id}"
      )
      
      # 6. Turbo Drive로 페이지 새로고침 (Rails 8 방식)
      Turbo::StreamsChannel.broadcast_action_to(
        "crawling_session_#{@session.id}",
        action: "refresh"
      )
      
      Rails.logger.info "[Broadcast] Completion updates sent successfully with page refresh"
    rescue => e
      Rails.logger.error "[Broadcast] Completion broadcast error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
  
  def build_initial_steps_data
    CRAWLING_STEPS.map do |number, step_info|
      { 
        number: step_info[:number], 
        name: step_info[:name], 
        status: 'waiting',
        sub_steps: step_info[:sub_steps],
        sub_step: nil,
        progress: 0
      }
    end
  end

  def current_step_name(step_number)
    CRAWLING_STEPS.dig(step_number, :name) || "대기 중"
  end
  
  def set_turbo_frame_request_variant
    request.variant = :turbo_frame if turbo_frame_request?
  end
end