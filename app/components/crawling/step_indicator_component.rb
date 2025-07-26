# frozen_string_literal: true

class Crawling::StepIndicatorComponent < ApplicationComponent
  Step = Struct.new(:number, :name, :status, :sub_step, :sub_steps, keyword_init: true)

  def initialize(steps:, current_step: 0, current_sub_step: nil)
    @steps = steps.map { |s| Step.new(**s.symbolize_keys) }
    @current_step = current_step
    @current_sub_step = current_sub_step
  end

  private

  attr_reader :steps, :current_step, :current_sub_step

  def step_classes(step)
    base = safe_classes(
      "relative flex flex-col items-center",
      "bg-white dark:bg-gray-800",
      "border-2 rounded-xl p-6",
      "transition-all duration-300"
    )

    status_classes = case step.status.to_s
    when 'completed'
      "border-green-500 bg-green-50 dark:bg-green-900/20"
    when 'running'
      "border-blue-500 bg-blue-50 dark:bg-blue-900/20"
    when 'error'
      "border-red-500 bg-red-50 dark:bg-red-900/20"
    else
      "border-transparent"
    end

    safe_classes(base, status_classes)
  end

  def step_number_classes(step)
    base = safe_classes(
      "w-12 h-12 rounded-full",
      "flex items-center justify-center",
      "text-lg font-bold mb-3",
      "transition-all duration-300"
    )

    status_classes = case step.status.to_s
    when 'completed'
      "bg-green-500 text-white"
    when 'running'
      "bg-blue-500 text-white animate-pulse"
    when 'error'
      "bg-red-500 text-white"
    else
      "bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-400"
    end

    safe_classes(base, status_classes)
  end

  def step_status_text(step)
    case step.status.to_s
    when 'completed' then '완료'
    when 'running' then '진행 중'
    when 'error' then '오류'
    else '대기'
    end
  end
end