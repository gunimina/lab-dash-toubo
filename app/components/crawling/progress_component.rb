# frozen_string_literal: true

class Crawling::ProgressComponent < ApplicationComponent
  def initialize(current_step:, total_steps: 4, progress: 0, step_name: nil)
    @current_step = current_step
    @total_steps = total_steps
    @progress = progress
    @step_name = step_name
  end

  private

  attr_reader :current_step, :total_steps, :progress, :step_name

  def container_classes
    safe_classes(
      "bg-white dark:bg-gray-800",
      "rounded-xl shadow-sm",
      "border border-gray-200 dark:border-gray-700",
      "p-5"
    )
  end

  def progress_bar_classes
    safe_classes(
      "bg-blue-600",
      "h-2 rounded-full",
      "transition-all duration-500 ease-out"
    )
  end

  def step_text
    "#{current_step}/#{total_steps} - #{step_name || '대기 중'}"
  end
end