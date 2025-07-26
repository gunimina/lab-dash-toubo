# frozen_string_literal: true

class Crawling::StatusCardComponent < ApplicationComponent
  def initialize(title:, value:, icon:, status: :idle, dom_id: nil)
    @title = title
    @value = value
    @icon = icon
    @status = status
    @dom_id = dom_id
  end

  private

  attr_reader :title, :value, :icon, :status

  def component_id
    @dom_id || dom_id(self, title.parameterize)
  end

  def card_classes
    safe_classes(
      "bg-white dark:bg-gray-800",
      "rounded-xl shadow-sm",
      "border border-gray-200 dark:border-gray-700",
      "p-5 transition-all duration-200"
    )
  end

  def icon_classes
    safe_classes(
      "w-6 h-6",
      icon_color_class
    )
  end

  def icon_color_class
    case status
    when :running then "text-blue-600 dark:text-blue-400 animate-pulse"
    when :completed then "text-green-600 dark:text-green-400"
    when :error then "text-red-600 dark:text-red-400"
    else "text-gray-600 dark:text-gray-400"
    end
  end

  def value_classes
    safe_classes(
      "text-2xl font-bold",
      "text-gray-900 dark:text-white"
    )
  end
end