module IconHelper
  # 아이콘 매핑을 중앙에서 관리
  ICON_MAPPINGS = {
    # 기본 액션
    play: 'play',
    pause: 'pause',
    stop: 'square',
    refresh: 'rotate-cw',
    reset: 'rotate-cw',
    
    # 상태 아이콘
    check: 'check',
    check_circle: 'check-circle',
    warning: 'alert-triangle',
    error: 'x-circle',
    info: 'info',
    
    # UI 아이콘
    terminal: 'terminal',
    cloud_download: 'cloud-download',
    clock: 'clock',
    sun: 'sun',
    moon: 'moon',
    wifi: 'wifi',
    wifi_off: 'x',
    close: 'x',
    more: 'more-horizontal',
    inbox: 'inbox',
    
    # 특수 아이콘
    loading: 'rotate-cw'
  }.freeze
  
  def app_icon(name, options = {})
    icon_name = ICON_MAPPINGS[name.to_sym] || name.to_s
    css_class = options[:class] || 'w-5 h-5'
    
    # 로딩 애니메이션 자동 추가
    if name.to_sym == :loading || options[:animate_spin]
      css_class += ' animate-spin'
    end
    
    lucide_icon(icon_name, class: css_class)
  end
end