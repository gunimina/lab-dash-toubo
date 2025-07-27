# frozen_string_literal: true

class Crawling::ControlButtonsComponent < ApplicationComponent
  def initialize(status:)
    @status = status
  end

  private

  attr_reader :status

  # 버튼 설정
  BUTTON_CONFIG = {
    start: {
      text: '크롤링 시작',
      icon: 'play',
      color: 'purple',
      action: 'click->crawling-monitor#start'
    },
    pause: {
      text: '일시정지',
      icon: 'pause',
      color: 'yellow',
      action: 'click->crawling-monitor#pause'
    },
    resume: {
      text: '재개',
      icon: 'play',
      color: 'green',
      action: 'click->crawling-monitor#resume'
    },
    stop: {
      text: '중지',
      icon: 'square',
      color: 'red',
      action: 'click->crawling-monitor#stop'
    },
    reset: {
      text: '초기화',
      icon: 'rotate-cw',
      color: 'red',
      action: 'click->crawling-monitor#reset'
    },
    confirm: {
      text: '확인',
      icon: 'check',
      color: 'blue',
      action: 'click->crawling-monitor#confirmComplete'
    }
  }.freeze

  # 색상별 CSS 클래스
  COLOR_CLASSES = {
    'purple' => 'bg-purple-600 hover:bg-purple-700 text-white',
    'yellow' => 'bg-yellow-600 hover:bg-yellow-700 text-white',
    'green' => 'bg-green-600 hover:bg-green-700 text-white',
    'red' => 'bg-red-600 hover:bg-red-700 text-white',
    'gray' => 'bg-gray-600 hover:bg-gray-700 text-white',
    'blue' => 'bg-blue-600 hover:bg-blue-700 text-white'
  }.freeze

  def visible_buttons
    case status
    when 'idle', 'stopped', 'completed', 'error', 'disconnected'
      [:start, :reset]
    when 'running'
      [:pause, :stop]
    when 'paused'
      [:resume, :stop]
    when 'starting'
      [:stop]
    else
      []
    end
  end

  def button_classes(button_key)
    config = BUTTON_CONFIG[button_key]
    color_class = COLOR_CLASSES[config[:color]] || COLOR_CLASSES['gray']
    "inline-flex items-center px-4 py-2 rounded-lg font-medium transition-colors cursor-pointer #{color_class}"
  end

  def button_config(button_key)
    BUTTON_CONFIG[button_key]
  end
end