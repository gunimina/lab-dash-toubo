class CrawlingSession < ApplicationRecord
  include CrawlerConstants
  
  has_many :crawling_progresses, dependent: :destroy
  
  validates :crawling_type, presence: true
  validates :status, inclusion: { 
    in: VALID_STATUSES,
    message: "must be one of: #{VALID_STATUSES.join(', ')}"
  }
  
  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :completed, -> { where(status: CRAWLER_STATUS[:completed]) }
  
  def self.current_session
    where(status: 'running').last
  end
  
  def active?
    %w[starting running paused].include?(status)
  end
  
  def completed?
    status == 'completed'
  end
  
  def duration
    return nil unless started_at
    
    end_time = ended_at || Time.current
    ((end_time - started_at) / 60).round # 분 단위
  end
  
  def duration_in_words
    return nil unless duration
    
    minutes = duration
    hours = minutes / 60
    
    if hours > 0
      "#{hours}시간 #{minutes % 60}분"
    else
      "#{minutes}분"
    end
  end
end
