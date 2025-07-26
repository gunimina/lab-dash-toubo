module ApplicationHelper
  include CrawlerConstants
  include IconHelper
  
  # 뷰에서 크롤러 상태 상수에 접근하기 위한 헬퍼
  def crawler_status
    CRAWLER_STATUS
  end
  
  def crawling_type
    CRAWLING_TYPE
  end
  
  def crawling_steps
    CRAWLING_STEPS
  end
  # 상태에 따른 배지 표시
  def status_badge(status, size: :md)
    size_classes = case size
    when :sm then "px-2 py-1 text-xs"
    when :md then "px-3 py-1.5 text-sm"
    when :lg then "px-4 py-2 text-base"
    else "px-3 py-1.5 text-sm"
    end
    
    base_classes = "inline-flex items-center font-medium rounded-full #{size_classes}"
    
    status_config = case status.to_s.downcase
    when 'running', 'active', 'success', 'completed'
      {
        bg: "bg-green-100 dark:bg-green-900",
        text: "text-green-800 dark:text-green-200",
        icon: 'play-circle'
      }
    when 'paused', 'pending', 'warning'
      {
        bg: "bg-yellow-100 dark:bg-yellow-900",
        text: "text-yellow-800 dark:text-yellow-200",
        icon: 'pause-circle'
      }
    when 'stopped', 'failed', 'error'
      {
        bg: "bg-red-100 dark:bg-red-900",
        text: "text-red-800 dark:text-red-200",
        icon: 'stop-circle'
      }
    else
      {
        bg: "bg-gray-100 dark:bg-gray-900",
        text: "text-gray-800 dark:text-gray-200",
        icon: 'info'
      }
    end
    
    content_tag :span, class: "#{base_classes} #{status_config[:bg]} #{status_config[:text]}" do
      concat lucide_icon(status_config[:icon], class: "w-4 h-4 mr-1 inline")
      concat status.to_s.humanize
    end
  end
  
  # 카드 컨테이너
  def card_container(size: :md, shadow: :DEFAULT, &block)
    classes = [
      "bg-white dark:bg-gray-800",
      DesignSystem::SIZES[:radius][:lg],
      DesignSystem::SIZES[:card][size],
      DesignSystem::SHADOWS[shadow],
      DesignSystem::TRANSITIONS[:DEFAULT]
    ].join(' ')
    
    content_tag :div, class: classes, &block
  end
  
  # 버튼 클래스 헬퍼
  def button_classes(variant = :primary, size = :md)
    base_classes = [
      "inline-flex items-center justify-center font-medium",
      "rounded-lg", # DesignSystem 대신 직접 명시
      DesignSystem::SIZES[:button][size],
      "transition-all duration-150", # 직접 명시
      "focus:outline-none focus:ring-2 focus:ring-offset-2",
      "disabled:opacity-50 disabled:cursor-not-allowed"
    ].join(' ')
    
    variant_classes = case variant
    when :primary
      "bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-600"
    when :secondary
      "bg-gray-200 text-gray-900 hover:bg-gray-300 dark:bg-gray-700 dark:text-gray-100 dark:hover:bg-gray-600 focus:ring-gray-500"
    when :danger
      "bg-red-600 text-white hover:bg-red-700 focus:ring-red-600"
    when :warning
      "bg-yellow-500 text-white hover:bg-yellow-600 focus:ring-yellow-500"
    when :ghost
      "text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800 focus:ring-gray-500"
    else
      ""
    end
    
    "#{base_classes} #{variant_classes}"
  end
  
  # 커스텀 버튼 헬퍼
  def custom_button(text, variant: :primary, size: :md, icon: nil, **options)
    options[:class] = "#{button_classes(variant, size)} #{options[:class]}"
    
    button_tag text, options do
      if icon
        concat lucide_icon(icon, class: "w-4 h-4 mr-2 inline")
      end
      concat text
    end
  end
  
  # 진행률 바
  def progress_bar(progress, height: 'h-2', color: :primary)
    progress = progress.to_i.clamp(0, 100)
    
    color_classes = case color
    when :primary then "bg-blue-600"
    when :success then "bg-green-600"
    when :warning then "bg-yellow-600"
    when :danger then "bg-red-600"
    else "bg-blue-600"
    end
    
    content_tag :div, class: "w-full bg-gray-200 dark:bg-gray-700 rounded-full #{height} overflow-hidden" do
      content_tag :div, '',
        class: "#{color_classes} #{height} rounded-full transition-all duration-300",
        style: "width: #{progress}%"
    end
  end
  
  # 알림 메시지
  def alert_box(message, type: :info, dismissible: true)
    type_config = {
      info: { bg: 'bg-blue-50 dark:bg-blue-900/20', text: 'text-blue-800 dark:text-blue-200', icon: 'info' },
      success: { bg: 'bg-green-50 dark:bg-green-900/20', text: 'text-green-800 dark:text-green-200', icon: 'check-circle' },
      warning: { bg: 'bg-yellow-50 dark:bg-yellow-900/20', text: 'text-yellow-800 dark:text-yellow-200', icon: 'alert-triangle' },
      error: { bg: 'bg-red-50 dark:bg-red-900/20', text: 'text-red-800 dark:text-red-200', icon: 'x-circle' }
    }[type]
    
    content_tag :div, 
      class: "#{type_config[:bg]} #{type_config[:text]} p-4 #{DesignSystem::SIZES[:radius][:md]} flex items-start",
      data: { controller: dismissible ? 'alert' : nil } do
      concat lucide_icon(type_config[:icon], class: "w-5 h-5 mr-3 flex-shrink-0")
      concat content_tag(:div, message, class: 'flex-1')
      if dismissible
        concat custom_button('', variant: :ghost, size: :sm, icon: 'x', 
                           data: { action: 'click->alert#dismiss' },
                           class: 'ml-auto -mr-2 -mt-2')
      end
    end
  end
  
  # 섹션 헤더
  def section_header(title, subtitle: nil, actions: nil)
    content_tag :div, class: 'flex items-start justify-between mb-6' do
      concat(
        content_tag(:div) do
          concat content_tag(:h2, title, class: 'text-2xl font-semibold text-gray-900 dark:text-white')
          if subtitle
            concat content_tag(:p, subtitle, class: 'mt-1 text-sm text-gray-500 dark:text-gray-400')
          end
        end
      )
      if actions
        concat content_tag(:div, actions, class: 'flex items-center space-x-3')
      end
    end
  end
  
  # 로딩 스피너
  def loading_spinner(size: :md, text: nil)
    spinner_sizes = { sm: 'w-4 h-4', md: 'w-6 h-6', lg: 'w-8 h-8' }
    
    content_tag :div, class: 'flex items-center space-x-3' do
      concat content_tag(:div, '', class: "#{spinner_sizes[size]} animate-spin rounded-full border-2 border-gray-300 border-t-blue-600")
      if text
        concat content_tag(:span, text, class: 'text-gray-600 dark:text-gray-400')
      end
    end
  end
  
  # 빈 상태 표시
  def empty_state(title:, description: nil, icon: 'inbox', action: nil)
    content_tag :div, class: 'text-center py-12' do
      concat lucide_icon(icon, class: "w-16 h-16 text-gray-300 dark:text-gray-600 mb-4 mx-auto")
      concat content_tag(:h3, title, class: 'text-lg font-medium text-gray-900 dark:text-white mb-2')
      if description
        concat content_tag(:p, description, class: 'text-sm text-gray-500 dark:text-gray-400 mb-6')
      end
      if action
        concat action
      end
    end
  end
  
  # 크롤링 단계 관련 헬퍼들
  def status_text(status)
    case status.to_s
    when 'idle' then '대기 중'
    when 'starting' then '시작 중'
    when 'running' then '진행 중'
    when 'paused' then '일시정지됨'
    when 'completed' then '완료됨'
    when 'stopped' then '중지됨'
    when 'error' then '오류 발생'
    when 'disconnected' then '연결 끊김'
    else status.to_s.humanize
    end
  end
  
  def status_color_class(status)
    case status.to_s
    when 'running' then "text-blue-600 dark:text-blue-400"
    when 'paused' then "text-yellow-600 dark:text-yellow-400"
    when 'completed' then "text-green-600 dark:text-green-400"
    when 'stopped' then "text-red-600 dark:text-red-400"
    when 'failed', 'error' then "text-red-600 dark:text-red-400"
    else "text-gray-600 dark:text-gray-400"
    end
  end
  
  def status_badge_color(status)
    case status.to_s
    when 'running' then "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200"
    when 'paused' then "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200"
    when 'completed' then "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
    when 'stopped' then "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
    when 'failed', 'error' then "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
    else "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200"
    end
  end
  
  def estimated_time(status)
    return '-' unless status[:status] == 'running'
    
    # 간단한 예상 시간 계산
    overall = status[:overall_progress] || 0
    return '계산 중...' if overall < 5
    
    # 전체 4-5시간 기준
    remaining_percent = 100 - overall
    remaining_minutes = (remaining_percent * 4.5 * 60 / 100).to_i
    
    hours = remaining_minutes / 60
    minutes = remaining_minutes % 60
    
    if hours > 0
      "약 #{hours}시간 #{minutes}분"
    else
      "약 #{minutes}분"
    end
  end
  
  def step_number_classes(status)
    case status.to_s
    when 'completed'
      'bg-green-500'
    when 'running'
      'bg-blue-500 animate-pulse'
    when 'error'
      'bg-red-500'
    else
      'bg-gray-200 dark:bg-gray-700'
    end
  end
  
  def step_status_text(status)
    case status.to_s
    when 'completed' then '완료'
    when 'running' then '진행 중'
    when 'error' then '오류'
    when 'paused' then '일시정지'
    else '대기'
    end
  end
  
  # 일반 카드 클래스 (card_container와 구분)
  def card_classes(size: :md)
    base = "bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 transition-all duration-200"
    padding = case size
    when :sm then 'p-4'
    when :md then 'p-5'
    when :lg then 'p-6'
    else 'p-5'
    end
    "#{base} #{padding}"
  end
  
  # 로그 엔트리 스타일링
  def log_entry_class(type)
    case type.to_s
    when 'error' then 'text-red-400'
    when 'warning' then 'text-yellow-400'
    when 'success' then 'text-green-400'
    else 'text-gray-300'
    end
  end
  
  def log_text_class(type)
    case type.to_s
    when 'error' then 'text-red-300'
    when 'warning' then 'text-yellow-300'  
    when 'success' then 'text-green-300'
    else 'text-gray-100'
    end
  end
  
  # Alert 헬퍼 메서드들
  def alert_classes(type)
    base = "border"
    
    case type.to_sym
    when :success
      "#{base} bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800 text-green-800 dark:text-green-200"
    when :error
      "#{base} bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-800 dark:text-red-200"
    when :warning
      "#{base} bg-yellow-50 dark:bg-yellow-900/20 border-yellow-200 dark:border-yellow-800 text-yellow-800 dark:text-yellow-200"
    else
      "#{base} bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800 text-blue-800 dark:text-blue-200"
    end
  end

  def alert_icon(type)
    icon_name = case type.to_sym
    when :success then "check-circle"
    when :error then "x-circle"
    when :warning then "alert-triangle"
    else "info"
    end
    
    color_class = case type.to_sym
    when :success then "text-green-600 dark:text-green-400"
    when :error then "text-red-600 dark:text-red-400"
    when :warning then "text-yellow-600 dark:text-yellow-400"
    else "text-blue-600 dark:text-blue-400"
    end
    
    lucide_icon(icon_name, class: "w-5 h-5 #{color_class} mr-3 flex-shrink-0")
  end
end
