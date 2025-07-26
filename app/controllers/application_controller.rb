require 'net/http'
require 'json'

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  before_action :check_server_status
  
  # Turbo Stream 요청에 대해 레이아웃 비활성화
  layout -> { false if request.format.turbo_stream? }
  
  private
  
  def check_server_status
    @server_connected = check_crawler_connection
  end
  
  def check_crawler_connection
    uri = URI("http://localhost:3334/api/health")
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      # JSON:API 형식으로 응답을 확인
      data.dig('data', 'attributes', 'status') == 'ok'
    else
      false
    end
  rescue => e
    Rails.logger.error "Crawler connection check failed: #{e.message}"
    false
  end
end
