# frozen_string_literal: true

class Crawling::StepIndicatorV2Component < ApplicationComponent
  def initialize(steps:, current_step: 0)
    @steps = steps
    @current_step = current_step
  end

  private

  attr_reader :steps, :current_step

  # 모든 CSS 클래스를 정적으로 정의
  STEP_CLASSES = {
    base: "relative flex flex-col items-center bg-white dark:bg-gray-800 border-2 rounded-xl p-6 transition-all duration-300",
    completed: "border-green-500 bg-green-50 dark:bg-green-900/20",
    running: "border-blue-500 bg-blue-50 dark:bg-blue-900/20",
    error: "border-red-500 bg-red-50 dark:bg-red-900/20",
    waiting: "border-gray-300 dark:border-gray-600"
  }.freeze

  NUMBER_CLASSES = {
    base: "w-12 h-12 rounded-full flex items-center justify-center text-lg font-bold mb-3 transition-all duration-300",
    completed: "bg-green-500 text-white",
    running: "bg-blue-500 text-white",
    error: "bg-red-500 text-white",
    waiting: "bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-400"
  }.freeze

  STATUS_TEXT = {
    'completed' => '완료',
    'running' => '진행 중',
    'error' => '오류',
    'waiting' => '대기'
  }.freeze

  def step_container_classes(step)
    status = step[:status].to_s
    base_class = STEP_CLASSES[:base]
    status_class = STEP_CLASSES[status.to_sym] || STEP_CLASSES[:waiting]
    "#{base_class} #{status_class}"
  end

  def step_number_classes(step)
    status = step[:status].to_s
    base_class = NUMBER_CLASSES[:base]
    status_class = NUMBER_CLASSES[status.to_sym] || NUMBER_CLASSES[:waiting]
    "#{base_class} #{status_class}"
  end

  def step_status_text(step)
    STATUS_TEXT[step[:status].to_s] || '대기'
  end
end