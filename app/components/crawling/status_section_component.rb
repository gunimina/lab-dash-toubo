# frozen_string_literal: true

class Crawling::StatusSectionComponent < ApplicationComponent
  def initialize(status:)
    @status = status
  end

  private

  attr_reader :status

  # 상태별 설정
  STATUS_CONFIG = {
    'idle' => {
      title: '대기 중',
      description: '크롤링을 시작할 준비가 되었습니다.',
      icon: 'circle',
      color: 'gray'
    },
    'starting' => {
      title: '시작 중',
      description: '크롤링을 시작하고 있습니다...',
      icon: 'loader-2',
      color: 'yellow'
    },
    'running' => {
      title: '실행 중',
      description: '크롤링이 진행 중입니다.',
      icon: 'play-circle',
      color: 'blue'
    },
    'paused' => {
      title: '일시정지',
      description: '크롤링이 일시정지되었습니다.',
      icon: 'pause-circle',
      color: 'yellow'
    },
    'stopped' => {
      title: '중지됨',
      description: '크롤링이 중지되었습니다.',
      icon: 'stop-circle',
      color: 'red'
    },
    'completed' => {
      title: '완료',
      description: '크롤링이 완료되었습니다.',
      icon: 'check-circle',
      color: 'green'
    },
    'error' => {
      title: '오류',
      description: '크롤링 중 오류가 발생했습니다.',
      icon: 'alert-circle',
      color: 'red'
    },
    'disconnected' => {
      title: '연결 끊김',
      description: '크롤러 서버와 연결할 수 없습니다.',
      icon: 'wifi-off',
      color: 'gray'
    }
  }.freeze

  # CSS 클래스 맵핑
  COLOR_CLASSES = {
    'gray' => {
      bg: 'bg-gray-50 dark:bg-gray-900',
      border: 'border-gray-200 dark:border-gray-700',
      icon: 'text-gray-500 dark:text-gray-400',
      title: 'text-gray-900 dark:text-gray-100',
      description: 'text-gray-600 dark:text-gray-400'
    },
    'blue' => {
      bg: 'bg-blue-50 dark:bg-blue-900/20',
      border: 'border-blue-200 dark:border-blue-700',
      icon: 'text-blue-600 dark:text-blue-400',
      title: 'text-blue-900 dark:text-blue-100',
      description: 'text-blue-700 dark:text-blue-300'
    },
    'yellow' => {
      bg: 'bg-yellow-50 dark:bg-yellow-900/20',
      border: 'border-yellow-200 dark:border-yellow-700',
      icon: 'text-yellow-600 dark:text-yellow-400',
      title: 'text-yellow-900 dark:text-yellow-100',
      description: 'text-yellow-700 dark:text-yellow-300'
    },
    'green' => {
      bg: 'bg-green-50 dark:bg-green-900/20',
      border: 'border-green-200 dark:border-green-700',
      icon: 'text-green-600 dark:text-green-400',
      title: 'text-green-900 dark:text-green-100',
      description: 'text-green-700 dark:text-green-300'
    },
    'red' => {
      bg: 'bg-red-50 dark:bg-red-900/20',
      border: 'border-red-200 dark:border-red-700',
      icon: 'text-red-600 dark:text-red-400',
      title: 'text-red-900 dark:text-red-100',
      description: 'text-red-700 dark:text-red-300'
    }
  }.freeze

  def status_config
    STATUS_CONFIG[status] || STATUS_CONFIG['idle']
  end

  def color_classes
    COLOR_CLASSES[status_config[:color]] || COLOR_CLASSES['gray']
  end

  def animation_class
    case status
    when 'running', 'starting'
      'animate-pulse'
    else
      ''
    end
  end
end