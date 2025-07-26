class Admin::InitialCrawlingController < ApplicationController
  include CrawlerConstants
  
  skip_before_action :verify_authenticity_token, only: [:webhook, :reset]
  before_action :set_turbo_frame_request_variant, only: [:start, :pause, :resume, :stop, :reset]
  
  def index
    @status = fetch_crawler_status
    @steps = build_steps_data
    
    # 현재 실행 중인 세션이 있는지 확인
    if ['running', 'paused'].include?(@status[:status])
      @session = CrawlingSession.where(status: ['running', 'paused', 'starting']).last
    end
    
    # 완료된 세션 확인
    @last_completed_session = CrawlingSession.where(status: 'completed').order(ended_at: :desc).first
    
    # 크롤링 이력 (최근 5개)
    @crawling_history = CrawlingSession.includes(:crawling_progresses)
                                      .order(created_at: :desc)
                                      .limit(5)
    
    Rails.logger.info "[Index] Status: #{@status[:status]}, Session: #{@session&.id}"
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
        streams << turbo_stream.replace("control-panel", 
          partial: "admin/initial_crawling/control_panel", 
          locals: { session: @session, status: CRAWLER_STATUS[:running] })
        
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
          turbo_stream.replace("control-panel",
            partial: "admin/initial_crawling/control_panel",
            locals: { session: @session, status: @status[:status] }),
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
          turbo_stream.replace("control-panel",
            partial: "admin/initial_crawling/control_panel",
            locals: { session: @session, status: @status[:status] }),
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
    end
    
    Rails.logger.info "[InitialCrawling#reset] Result: #{result.inspect}"
    
    if request.headers["Accept"]&.include?("text/vnd.turbo-stream.html") || request.headers["Turbo-Frame"]
      # 초기 상태 데이터 준비
      @status = { status: CRAWLER_STATUS[:idle], current_step: 0, overall_progress: 0 }
      @steps = build_steps_data
      
      render turbo_stream: [
        turbo_stream.replace("control-panel", 
          partial: "admin/initial_crawling/control_panel", 
          locals: { session: nil, status: CRAWLER_STATUS[:idle] }),
        turbo_stream.replace("step-indicator",
          partial: "admin/initial_crawling/step_indicator",
          locals: { steps: @steps, current_step: 0 }),
        turbo_stream.append("notifications",
          partial: "shared/alert",
          locals: { message: "초기화가 완료되었습니다.", type: :success })
      ]
    else
      redirect_to admin_initial_crawling_index_path, notice: "초기화가 완료되었습니다."
    end
  end

  def status
    @session = CrawlingSession.find_by(id: params[:id])
    return render json: { error: 'Session not found' }, status: :not_found unless @session
    
    @status = fetch_crawler_status
    
    Rails.logger.info "[Status] API Response: #{@status.inspect}"
    
    # Node.js API 상태에서 진행률 정보 가져오기
    current_step = @status[:currentStep] || @status[:current_step] || 1
    overall_progress = @status[:progress] || @status[:overall_progress] || 0
    
    # DB에서 추가 정보 가져오기
    current_progress = CrawlingProgress.where(step_number: current_step).first
    step_progress = current_progress&.current_progress || overall_progress
    
    Rails.logger.info "[Status] Current step: #{current_step}, Overall progress: #{overall_progress}, Step progress: #{step_progress}"
    
    # 상태 정보 업데이트
    @status[:current_step] = current_step
    @status[:overall_progress] = overall_progress
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("step-indicator",
            partial: "admin/initial_crawling/step_indicator",
            locals: { 
              steps: build_steps_data,
              current_step: current_step
            }),
          turbo_stream.replace("control-panel",
            partial: "admin/initial_crawling/control_panel",
            locals: { session: @session, status: @status[:status] })
        ]
      end
      format.json do
        render json: @status
      end
    end
  end

  def webhook
    Rails.logger.info "[Webhook] Received params: #{params.inspect}"
    
    # 세션 찾기
    session_id = params[:session_id] || params[:sessionId]
    Rails.logger.info "[Webhook] Looking for session ID: #{session_id}"
    
    # 세션 ID가 있으면 찾고, 없으면 현재 실행 중인 세션 찾기
    if session_id.present?
      @session = CrawlingSession.find_by(id: session_id)
    else
      # 실행 중인 세션 찾기
      @session = CrawlingSession.where(status: ['running', 'paused', 'starting']).last
      Rails.logger.info "[Webhook] No session ID provided, found running session: #{@session&.id}"
    end
    
    # 세션이 없으면 에러 반환
    unless @session
      Rails.logger.error "[Webhook] Session not found for ID: #{session_id}"
      Rails.logger.error "[Webhook] All params: #{params.to_unsafe_h}"
      render json: { error: 'Session not found', session_id: session_id }, status: :unprocessable_entity
      return
    end
    
    # 진행상황 업데이트 처리
    step = extract_step_from_params
    message = params[:message] || ""
    
    # Step 1의 경우 진행률을 내부 단계에 맞춰 조정
    if step == 1
      # 다양한 메시지 패턴 확인 (4단계)
      progress = if message.match?(/카테고리|category|분류/i)
        10  # 내부 1단계: 0-25%
      elsif message.match?(/부모|parent|상위.*제품/i)
        35  # 내부 2단계: 26-50%
      elsif message.match?(/자식|child|하위.*제품|PHASE 1/i)
        60  # 내부 3단계: 51-75%
      elsif message.match?(/iframe|스펙|spec|PHASE 2/i)
        85  # 내부 4단계: 76-100%
      else
        extract_progress_from_params
      end
      
      Rails.logger.info "[Webhook] Step 1 - Message: #{message}, Progress: #{progress}"
    else
      progress = extract_progress_from_params
    end
    
    if step
      update_progress(step, progress, message)
      
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
        sub_step: nil
      }
    end
    
    # DB에서 진행상황 반영
    CrawlingProgress.all.each do |progress|
      step = steps[progress.step_number - 1]
      next unless step
      
      step[:status] = if progress.current_progress >= 100
                       'completed'
                     elsif progress.current_progress > 0
                       'running'
                     else
                       'waiting'
                     end
                     
      # Step 1의 경우 진행 중이면 내부 단계도 감지
      if progress.step_number == 1 && step[:status] == 'running'
        # 먼저 메시지로 감지 시도
        current_sub_step = detect_sub_step_from_message(progress.message)
        # 메시지로 감지 못하면 진행률로 추정
        current_sub_step ||= detect_sub_step_from_progress(progress)
        step[:sub_step] = current_sub_step
        Rails.logger.info "[BuildSteps] Step 1 sub_step set to: #{current_sub_step} from message: #{progress.message}"
      end
    end
    
    # 현재 진행 중인 단계가 DB에 없으면 직접 설정 (크롤러가 실행 중일 때만)
    if is_running && current_step_number > 0 && steps[current_step_number - 1]
      current_step = steps[current_step_number - 1]
      if current_step[:status] == 'waiting'
        current_step[:status] = 'running'
      end
    end
    
    Rails.logger.info "[BuildSteps] Final steps data: #{steps.inspect}"
    
    steps
  end
  
  def detect_sub_step_from_message(message)
    return nil if message.blank?
    
    Rails.logger.info "[DetectSubStep] Checking message: #{message}"
    
    sub_step = if message.match?(/카테고리|category|분류|=== 1단계/i)
      1
    elsif message.match?(/부모|parent|상위.*제품|=== 2단계/i)
      2
    elsif message.match?(/자식|child|하위.*제품|PHASE 1|기본.*크롤링/i)
      3
    elsif message.match?(/iframe|스펙|spec|PHASE 2/i)
      4
    else
      nil
    end
    
    Rails.logger.info "[DetectSubStep] Detected sub_step: #{sub_step}"
    sub_step
  end
  
  def detect_sub_step_from_progress(progress)
    return nil unless progress
    
    # 진행률 기반 추정 (4단계)
    if progress.current_progress <= 25
      1  # 카테고리 수집
    elsif progress.current_progress <= 50
      2  # 부모상품 수집
    elsif progress.current_progress <= 75
      3  # 자식상품 수집
    else
      4  # iframe 스펙 크롤링
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
    
    render turbo_stream: turbo_stream.replace("control-panel",
      partial: "admin/initial_crawling/control_panel",
      locals: { session: @session, status: @status[:status] }),
      layout: false
  end

  def webhook_url
    "#{request.protocol}#{request.host_with_port}/admin/initial_crawling/webhook"
  end

  def extract_step_from_params
    # 메시지에서 단계 추출 로직
    message = params[:message] || ""
    
    # Step 1의 내부 단계들
    if message.include?("Step 0-1") || message.include?("Step 1") || 
       message.include?("카테고리") || message.include?("부모상품") || 
       message.include?("자식상품") || message.include?("PHASE")
      1
    elsif message.include?("Step 2") || message.include?("AI")
      2
    elsif message.include?("Step 3") || message.include?("카탈로그")
      3
    elsif message.include?("Step 4") || message.include?("데이터베이스")
      4
    else
      params[:step]&.to_i || 1  # 기본값 1
    end
  end

  def extract_progress_from_params
    # 진행률 추출 로직
    params[:progress]&.to_i || 0
  end

  def update_progress(step, progress, message)
    return unless @session
    
    crawling_progress = CrawlingProgress.find_or_create_by(
      crawling_session: @session,
      step_number: step
    )
    crawling_progress.update!(
      current_progress: progress,
      message: message,
      status: progress >= 100 ? 'completed' : 'running'
    )
    
    # Step 4가 100% 완료되면 세션 종료
    if step == 4 && progress >= 100
      @session.update!(
        status: CRAWLER_STATUS[:completed],
        ended_at: Time.current
      )
      Rails.logger.info "[UpdateProgress] Step 4 완료, 크롤링 세션 종료"
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
    Rails.logger.info "[Broadcast] Current step data: #{steps.find { |s| s[:number] == 1 }&.inspect}"
    
    begin
      # 모든 UI 요소 즉시 업데이트
      Turbo::StreamsChannel.broadcast_replace_to(
        "crawling_session_#{@session.id}",
        target: "step-indicator",
        partial: "admin/initial_crawling/step_indicator",
        locals: { steps: steps, current_step: current_step }
      )
      
      Turbo::StreamsChannel.broadcast_replace_to(
        "crawling_session_#{@session.id}",
        target: "control-panel",
        partial: "admin/initial_crawling/control_panel",
        locals: { session: @session, status: @status[:status] }
      )
      
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

  def current_step_name(step_number)
    CRAWLING_STEPS.dig(step_number, :name) || "대기 중"
  end
  
  def set_turbo_frame_request_variant
    request.variant = :turbo_frame if turbo_frame_request?
  end
end