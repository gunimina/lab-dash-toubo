class CrawlingProgress < ApplicationRecord
  belongs_to :crawling_session
  
  STEP_NAMES = {
    1 => '카테고리 및 제품 수집',
    2 => 'AI 데이터 처리',
    3 => '카탈로그 번호 생성',
    4 => '이미지 다운로드'
  }.freeze
  
  def self.current_step
    where(status: 'running').first&.step_number || 
    where(status: 'completed').maximum(:step_number)&.next || 
    1
  end
  
  def self.current_progress
    where(status: 'running').first&.current_progress || 0
  end
  
  def self.overall_progress
    completed_steps = where(status: 'completed').count
    current_step_progress = current_progress
    
    # 4단계 기준 전체 진행률 계산
    ((completed_steps * 25) + (current_step_progress * 0.25)).round
  end
  
  def step_name
    STEP_NAMES[step_number] || "단계 #{step_number}"
  end
end
