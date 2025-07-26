require 'net/http'
require 'json'

class InitialCrawlingController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:webhook, :start, :pause, :resume, :stop, :reset]
  
  CRAWLER_API_URL = "http://localhost:3334/api"
  
  def index
    # ApplicationController의 before_action이 이미 @server_connected를 설정함
    @status = get_crawler_status if @server_connected
    @progresses = CrawlingProgress.order(:step_number)
  end
  
  def status
    # 서버 연결 상태 확인 (ApplicationController의 메서드 사용)
    connected = check_crawler_connection
    status_info = connected ? get_crawler_status : { status: 'disconnected' }
    
    render json: {
      server_connected: connected,
      status: status_info[:status],
      progresses: CrawlingProgress.all.as_json,
      currentStep: CrawlingProgress.current_step,
      currentProgress: CrawlingProgress.current_progress,
      overallProgress: CrawlingProgress.overall_progress
    }
  end
  
  def start
    # 체크포인트 확인
    checkpoint = check_checkpoint
    resume_step = checkpoint ? checkpoint[:currentStep] : 1
    
    # 환경변수와 함께 크롤러 시작
    response = http_post("#{CRAWLER_API_URL}/crawl", {
      type: 'initial',
      webhookUrl: webhook_url,
      resumeStep: resume_step
    })
    
    # API는 success 필드 대신 message와 job을 반환
    if response[:message] == "Crawler started" && response[:job]
      # 크롤링 세션 생성
      CrawlingSession.create!(
        status: 'running',
        started_at: Time.current
      )
      
      render json: { success: true, message: "크롤링이 시작되었습니다.", resumedFrom: resume_step }
    else
      render json: { success: false, error: response[:error] || response[:message] || "크롤링 시작 실패" }
    end
  end
  
  def pause
    response = http_post("#{CRAWLER_API_URL}/pause")
    render json: response
  end
  
  def resume
    response = http_post("#{CRAWLER_API_URL}/resume")
    render json: response
  end
  
  def stop
    response = http_post("#{CRAWLER_API_URL}/stop")
    if response[:success]
      CrawlingSession.current_session&.update(
        status: 'stopped',
        ended_at: Time.current
      )
    end
    render json: response
  end
  
  def reset
    response = http_post("#{CRAWLER_API_URL}/full-setup/reset")
    if response[:success]
      CrawlingProgress.destroy_all
      CrawlingSession.destroy_all
    end
    render json: response
  end
  
  def backup
    response = http_post("#{CRAWLER_API_URL}/full-setup/backup")
    render json: response
  end
  
  def check_files
    response = http_get("#{CRAWLER_API_URL}/db-status")
    
    # DB에서 저장된 진행 상태 확인
    saved_progresses = CrawlingProgress.all.index_by(&:step_number)
    
    # 각 단계별 파일 존재 여부 확인
    step_details = {}
    
    # Step 1
    step1_files = check_step1_files_with_details
    step_details[1] = {
      completed: step1_files[:exists],
      files: step1_files[:files],
      saved_status: saved_progresses[1]
    }
    
    # Step 2
    step2_files = check_step2_files_with_details
    step_details[2] = {
      completed: step2_files[:exists],
      files: step2_files[:files],
      saved_status: saved_progresses[2]
    }
    
    # Step 3
    step3_files = check_step3_files_with_details
    step_details[3] = {
      completed: step3_files[:exists],
      files: step3_files[:files],
      saved_status: saved_progresses[3]
    }
    
    # Step 4 (Database)
    step_details[4] = {
      completed: response[:exists] || false,
      database: response,
      saved_status: saved_progresses[4]
    }
    
    # 전체 완료 여부
    all_completed = step_details.values.all? { |step| step[:completed] }
    
    # 마지막 세션 정보
    last_session = CrawlingSession.last
    
    render json: {
      completed: all_completed,
      steps: step_details,
      last_session: last_session,
      message: all_completed ? "초기 크롤링이 완료되었습니다. 초기화하시겠습니까?" : "초기 크롤링이 진행 중이거나 미완료 상태입니다."
    }
  end
  
  private
  
  def check_step1_files
    base_path = "/Users/macstudio/node/lab-shop-crawler/results/initial-setup/step1_source"
    required_files = ["categories.csv", "parents_basic.csv", "children_unique.csv"]
    
    required_files.all? do |file|
      File.exist?(File.join(base_path, file))
    end
  rescue
    false
  end
  
  def check_step2_files
    base_path = "/Users/macstudio/node/lab-shop-crawler/results/initial-setup/step2_processed"
    required_files = ["step2_product_page.csv"]
    
    required_files.all? do |file|
      File.exist?(File.join(base_path, file))
    end
  rescue
    false
  end
  
  def check_step3_files
    base_path = "/Users/macstudio/node/lab-shop-crawler/results/initial-setup/step3_newcat"
    # 가장 최근 파일 확인 (타임스탬프가 포함됨)
    Dir.glob(File.join(base_path, "parent_with_new_catalog_*.csv")).any? &&
    Dir.glob(File.join(base_path, "child_with_new_catalog_*.csv")).any?
  rescue
    false
  end
  
  def check_step1_files_with_details
    base_path = "/Users/macstudio/node/lab-shop-crawler/results/initial-setup/step1_source"
    required_files = ["categories.csv", "parents_basic.csv", "children_unique.csv"]
    
    files = required_files.map do |filename|
      filepath = File.join(base_path, filename)
      if File.exist?(filepath)
        {
          name: filename,
          path: filepath,
          size: format_file_size(File.size(filepath)),
          exists: true
        }
      else
        { name: filename, exists: false }
      end
    end
    
    { exists: files.all? { |f| f[:exists] }, files: files }
  rescue => e
    { exists: false, files: [], error: e.message }
  end
  
  def check_step2_files_with_details
    base_path = "/Users/macstudio/node/lab-shop-crawler/results/initial-setup/step2_processed"
    required_files = ["step2_product_page.csv"]
    
    files = required_files.map do |filename|
      filepath = File.join(base_path, filename)
      if File.exist?(filepath)
        {
          name: filename,
          path: filepath,
          size: format_file_size(File.size(filepath)),
          exists: true
        }
      else
        { name: filename, exists: false }
      end
    end
    
    { exists: files.all? { |f| f[:exists] }, files: files }
  rescue => e
    { exists: false, files: [], error: e.message }
  end
  
  def check_step3_files_with_details
    base_path = "/Users/macstudio/node/lab-shop-crawler/results/initial-setup/step3_newcat"
    
    parent_files = Dir.glob(File.join(base_path, "parent_with_new_catalog_*.csv"))
    child_files = Dir.glob(File.join(base_path, "child_with_new_catalog_*.csv"))
    
    files = []
    
    if parent_files.any?
      latest_parent = parent_files.max_by { |f| File.mtime(f) }
      files << {
        name: File.basename(latest_parent),
        path: latest_parent,
        size: format_file_size(File.size(latest_parent)),
        exists: true
      }
    end
    
    if child_files.any?
      latest_child = child_files.max_by { |f| File.mtime(f) }
      files << {
        name: File.basename(latest_child),
        path: latest_child,
        size: format_file_size(File.size(latest_child)),
        exists: true
      }
    end
    
    { exists: parent_files.any? && child_files.any?, files: files }
  rescue => e
    { exists: false, files: [], error: e.message }
  end
  
  def format_file_size(size)
    case size
    when 0..1023
      "#{size} B"
    when 1024..1048575
      "#{(size / 1024.0).round(1)} KB"
    when 1048576..1073741823
      "#{(size / 1048576.0).round(1)} MB"
    else
      "#{(size / 1073741824.0).round(2)} GB"
    end
  end
  
  # Webhook endpoint - Node.js로부터 진행상태 수신
  def webhook
    Rails.logger.info "Webhook received: #{params.inspect}"
    
    # 로그 메시지에서 진행 상태 추출
    message = params[:message] || params[:log_message] || ""
    
    # 단계 추출 (메시지에서 Step 정보 파싱)
    step = if message.include?("Step 0-1") || message.include?("통합 크롤링") || message.include?("카테고리")
      1
    elsif message.include?("Step 2") || message.include?("AI")
      2  
    elsif message.include?("Step 3") || message.include?("카탈로그")
      3
    elsif message.include?("Step 4") || message.include?("데이터베이스") || message.include?("이미지")
      4
    else
      params[:step] || params[:step_number] || 1
    end
    
    # 진행률 계산 (메시지에서 추출)
    progress = if match = message.match(/(\d+)\/(\d+)/)
      current, total = match[1].to_i, match[2].to_i
      total > 0 ? (current * 100 / total) : 0
    elsif message.include?("완료")
      100
    elsif message.include?("카테고리 수집 완료")
      10  # Step 1의 10%
    elsif message.include?("부모상품") && message.include?("개 발견")
      20  # Step 1의 20%
    elsif match = message.match(/자식상품.*\((\d+)\)/)
      # Step 1 진행중 - 단순하게 처리
      # 대부분 15-20분 내에 끝나므로 세부 진행률은 표시하지 않음
      50  # Step 1 진행중임을 표시하는 중간값
    elsif message.include?("iframe") || message.include?("추가 자식상품")
      # iframe 처리는 Step 1의 90-95%
      92
    else
      params[:progress] || params[:current_progress] || 0
    end
    
    status = params[:status] || (progress >= 100 ? 'completed' : 'running')
    
    # 단계 이름 설정
    step_names = {
      1 => "카테고리 및 제품 수집",
      2 => "AI 데이터 처리", 
      3 => "카탈로그 번호 생성",
      4 => "데이터베이스 저장"
    }
    
    # 진행상태 업데이트
    crawling_progress = CrawlingProgress.find_or_create_by(step_number: step.to_i)
    
    # 기본 정보 업데이트
    update_attrs = {
      step_name: step_names[step.to_i] || "단계 #{step}",
      current_progress: progress.to_i,
      status: status,
      message: message,
      updated_at: Time.current
    }
    
    # 시작 시간 기록
    if crawling_progress.started_at.nil? && progress.to_i > 0
      update_attrs[:started_at] = Time.current
    end
    
    # 완료 처리 및 파일 정보 저장
    if progress.to_i >= 100 || status == 'completed'
      update_attrs[:completed_at] = Time.current
      update_attrs[:status] = 'completed'
      
      # 각 단계별 완료 시 파일 정보 저장
      case step.to_i
      when 1
        files_info = check_step1_files_with_details
        if files_info[:exists]
          update_attrs[:output_files] = files_info[:files].map { |f| f[:name] }.join(',')
          update_attrs[:output_file_sizes] = files_info[:files].map { |f| f[:size] }.join(',')
        end
      when 2
        files_info = check_step2_files_with_details
        if files_info[:exists]
          update_attrs[:output_files] = files_info[:files].map { |f| f[:name] }.join(',')
          update_attrs[:output_file_sizes] = files_info[:files].map { |f| f[:size] }.join(',')
        end
      when 3
        files_info = check_step3_files_with_details
        if files_info[:exists]
          update_attrs[:output_files] = files_info[:files].map { |f| f[:name] }.join(',')
          update_attrs[:output_file_sizes] = files_info[:files].map { |f| f[:size] }.join(',')
        end
      when 4
        db_status = http_get("#{CRAWLER_API_URL}/db-status")
        if db_status[:exists]
          update_attrs[:output_files] = "lab-shop.db"
          update_attrs[:output_file_sizes] = db_status[:size]
          update_attrs[:record_count] = db_status[:records]
        end
      end
    end
    
    crawling_progress.update!(update_attrs)
    
    # 세션 업데이트
    if status == 'completed' && step.to_i == 4
      CrawlingSession.current_session&.update(
        status: 'completed',
        ended_at: Time.current
      )
    end
    
    render json: { success: true, received: { step: step, progress: progress } }
  end
  
  def get_crawler_status
    response = http_get("#{CRAWLER_API_URL}/status")
    Rails.logger.info "Crawler API response: #{response.inspect}"
    
    status_value = response.dig(:data, :attributes, :status) || 
                   response.dig("data", "attributes", "status")
    
    Rails.logger.info "Extracted status: #{status_value}"
    
    if status_value
      { status: status_value }
    else
      { status: 'unknown' }
    end
  rescue => e
    Rails.logger.error "Error getting crawler status: #{e.message}"
    { status: 'disconnected' }
  end
  
  def check_checkpoint
    response = http_get("#{CRAWLER_API_URL}/checkpoint")
    response[:success] ? response[:data] : nil
  rescue
    nil
  end
  
  def webhook_url
    "#{request.protocol}#{request.host_with_port}/webhook"
  end
  
  def webhook_request?
    action_name == 'webhook'
  end
  
  def http_get(url)
    uri = URI(url)
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      # deep_symbolize_keys를 사용하여 중첩된 해시도 심볼화
      JSON.parse(response.body).deep_symbolize_keys
    else
      { success: false, error: "HTTP #{response.code}" }
    end
  rescue => e
    { success: false, error: e.message }
  end
  
  def http_post(url, body = {})
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = body.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body).symbolize_keys
    else
      { success: false, error: "HTTP #{response.code}" }
    end
  rescue => e
    { success: false, error: e.message }
  end
end