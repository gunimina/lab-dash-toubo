require 'net/http'
require 'json'

class CrawlerService
  CRAWLER_API_URL = "http://localhost:3334"
  
  class << self
    include CrawlerConstants
    def get_status
      response = http_get("#{CRAWLER_API_URL}#{API_ENDPOINTS[:status]}")
      progress_response = http_get("#{CRAWLER_API_URL}#{API_ENDPOINTS[:progress]}")
      
      if response[:success]
        # Node.js API 응답 파싱
        data = response[:data]
        status = data.dig(:data, :attributes, :status) || 
                 data.dig("data", "attributes", "status") || 
                 'idle'
        
        # 현재 작업 정보 가져오기
        current_job = data.dig(:data, :attributes, :currentJob) ||
                     data.dig("data", "attributes", "currentJob")
        
        # 진행률 정보 가져오기
        progress_data = progress_response[:success] ? progress_response[:data] : {}
        
        # 시뮬레이션을 위한 임시 진행률 계산
        if status == 'running' && current_job
          # 경과 시간 기반 진행률 계산 (임시)
          started_at_str = current_job['startedAt'] || current_job[:startedAt]
          Rails.logger.info "[CrawlerService] Started at: #{started_at_str}"
          
          started_at = Time.parse(started_at_str.to_s)
          elapsed = Time.now - started_at
          Rails.logger.info "[CrawlerService] Elapsed time: #{elapsed} seconds"
          
          simulated_progress = [(elapsed / 2).to_i, 95].min # 0.5% per second, max 95%
          Rails.logger.info "[CrawlerService] Simulated progress: #{simulated_progress}%"
          
          # progress_data[:percentage]가 0이면 시뮬레이션 값 사용
          overall_progress = if progress_data[:percentage] && progress_data[:percentage] > 0
                              progress_data[:percentage]
                            else
                              simulated_progress
                            end
          Rails.logger.info "[CrawlerService] Overall progress: #{overall_progress}%"
        else
          overall_progress = progress_data[:percentage] || 0
        end
        
        # DB에서 실제 진행 중인 단계 확인
        current_progress = CrawlingProgress.where(status: 'running').first
        
        # 현재 단계 계산
        current_step = if status == 'idle' || status == 'disconnected'
                        0
                      elsif current_progress
                        current_progress.step_number
                      else
                        # DB에 정보가 없으면 완료된 단계 + 1
                        completed_step = CrawlingProgress.where(status: 'completed').maximum(:step_number) || 0
                        completed_step < 4 ? completed_step + 1 : 4
                      end
        
        {
          status: status,
          current_step: current_step,
          overall_progress: overall_progress,
          progress: overall_progress,
          currentStep: current_step,
          server_connected: true,
          current_job: current_job,
          processed: progress_data[:processed] || (overall_progress * 40).to_i,
          total: progress_data[:total] || 4000,
          current_item: progress_data[:current_item] || "Processing..."
        }
      else
        {
          status: 'disconnected',
          error: response[:error],
          server_connected: false
        }
      end
    end
    
    def start_initial_crawl(options = {})
      Rails.logger.info "[CrawlerService#start_initial_crawl] Received options: #{options.inspect}"
      
      url = "#{CRAWLER_API_URL}#{API_ENDPOINTS[:crawl]}"
      body = {
        type: CRAWLING_TYPE[:initial],
        webhookUrl: options[:webhook_url],
        sessionId: options[:session_id]
      }
      
      Rails.logger.info "[CrawlerService#start_initial_crawl] Built body: #{body.inspect}"
      Rails.logger.info "[CrawlerService#start_initial_crawl] CRAWLING_TYPE[:initial] = #{CRAWLING_TYPE[:initial]}"
      Rails.logger.info "[CrawlerService#start_initial_crawl] POST #{url} with body: #{body.inspect}"
      
      response = http_post(url, body)
      
      Rails.logger.info "[CrawlerService#start_initial_crawl] Raw response: #{response.inspect}"
      
      if response[:success] && response[:data]
        job_id = response[:data][:job][:id] || response[:data][:job][:type] || 'initial'
        Rails.logger.info "[CrawlerService#start_initial_crawl] Success! Job ID: #{job_id}"
        { success: true, job_id: job_id }
      else
        Rails.logger.info "[CrawlerService#start_initial_crawl] Failed! Error: #{response[:error]}"
        { success: false, error: response[:error] || 'Unknown error' }
      end
    end
    
    def pause
      http_post("#{CRAWLER_API_URL}#{API_ENDPOINTS[:pause]}")
    end
    
    def resume
      http_post("#{CRAWLER_API_URL}#{API_ENDPOINTS[:resume]}")
    end
    
    def stop
      http_post("#{CRAWLER_API_URL}#{API_ENDPOINTS[:stop]}")
    end
    
    def reset
      http_post("#{CRAWLER_API_URL}#{API_ENDPOINTS[:reset]}")
    end
    
    private
    
    def http_get(url)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        { success: true, data: JSON.parse(response.body, symbolize_names: true) }
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
        JSON.parse(response.body, symbolize_names: true).merge(success: true)
      else
        { success: false, error: "HTTP #{response.code}" }
      end
    rescue => e
      { success: false, error: e.message }
    end
    
    def calculate_overall_progress
      progresses = CrawlingProgress.all
      return 0 if progresses.empty?
      
      total = progresses.sum(&:current_progress)
      (total / 4.0).to_i
    end
  end
end