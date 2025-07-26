# frozen_string_literal: true

# ViewComponent configuration
Rails.application.config.to_prepare do
  # Ensure ViewComponent is loaded
  require 'view_component'
end