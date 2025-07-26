# frozen_string_literal: true

class Crawling::ControlButtonComponent < ApplicationComponent
  VARIANTS = {
    primary: "bg-blue-600 hover:bg-blue-700 text-white focus:ring-blue-600",
    secondary: "bg-gray-200 hover:bg-gray-300 text-gray-900 dark:bg-gray-700 dark:text-gray-100 dark:hover:bg-gray-600 focus:ring-gray-500",
    danger: "bg-red-600 hover:bg-red-700 text-white focus:ring-red-600",
    warning: "bg-yellow-500 hover:bg-yellow-600 text-white focus:ring-yellow-500"
  }.freeze

  # 간단하고 명확한 인터페이스
  def initialize(text:, action:, icon: nil, variant: :primary, confirm: nil, disabled: false)
    @text = text
    @action = action  # :start, :pause, :resume, :stop, :reset
    @icon = icon
    @variant = variant
    @confirm = confirm
    @disabled = disabled
  end

  private

  attr_reader :text, :action, :icon, :variant, :confirm, :disabled

  def button_classes
    safe_classes(
      "inline-flex items-center justify-center",
      "px-4 py-2 rounded-lg font-medium",
      "transition-all duration-150",
      "focus:outline-none focus:ring-2 focus:ring-offset-2",
      "disabled:opacity-50 disabled:cursor-not-allowed",
      VARIANTS[variant]
    )
  end

  def stimulus_action
    "click->crawling-monitor##{action}"
  end

  def data_attributes
    attrs = {
      action: stimulus_action
    }
    attrs[:confirm] = confirm if confirm
    attrs[:url] = action_url if action_url
    attrs
  end

  def action_url
    case action
    when :start then '/admin/initial_crawling/start'
    when :pause then '/admin/initial_crawling/pause'
    when :resume then '/admin/initial_crawling/resume'
    when :stop then '/admin/initial_crawling/stop'
    when :reset then '/admin/initial_crawling/reset'
    end
  end
  
  def disabled?
    disabled
  end
end