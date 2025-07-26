# frozen_string_literal: true

class SidebarComponent < ApplicationComponent
  def initialize(current_path:)
    @current_path = current_path
  end

  private

  def navigation_items
    [
      {
        title: "자료관리",
        icon: "database",
        id: "data-management",
        items: [
          { title: "초기 크롤링", path: admin_initial_crawling_index_path, icon: "cloud-download" },
          { title: "동기 크롤링", path: admin_sync_crawling_index_path, icon: "clock" },
          { title: "상품목록", path: admin_data_management_products_path, icon: "package" },
          { title: "DB 동기화", path: sync_admin_data_management_products_path, icon: "refresh-cw", method: :post, confirm: "크롤러 DB에서 상품 데이터를 동기화하시겠습니까?" }
        ]
      }
    ]
  end

  def is_active?(path)
    @current_path == path || @current_path&.start_with?(path.to_s)
  end

  def section_active?(section)
    section[:items].any? { |item| is_active?(item[:path]) }
  end

  def link_classes(active)
    base = "flex items-center space-x-3 px-4 py-2.5 rounded-lg text-sm font-medium transition-colors"
    if active
      "#{base} bg-blue-100 dark:bg-blue-900/30 shadow-sm text-blue-800 dark:text-blue-200"
    else
      "#{base} text-gray-600 dark:text-gray-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 hover:text-blue-700 dark:hover:text-blue-300"
    end
  end
end