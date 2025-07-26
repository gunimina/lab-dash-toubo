# frozen_string_literal: true

module Admin
  module DataManagement
    class ProductsController < ApplicationController
      before_action :set_product, only: [:show, :edit, :update, :destroy]

      def index
        @products = Product.where(parent_product_id: nil).includes(:child_products)
        @products = @products.page(params[:page])
        @search_query = params[:q]
        
        if @search_query.present?
          search_pattern = "%#{@search_query}%"
          @products = @products.where(
            "new_catalog_number LIKE ? OR korean_product_name LIKE ? OR description LIKE ? OR cat_no LIKE ?",
            search_pattern, search_pattern, search_pattern, search_pattern
          )
        end
        
        @products = @products.order(created_at: :desc)
      end

      def search
        @search_query = params[:q]
        
        if @search_query.present?
          search_pattern = "%#{@search_query}%"
          @products = Product.where(parent_product_id: nil)
                            .includes(:child_products)
                            .where(
                              "new_catalog_number LIKE ? OR korean_product_name LIKE ? OR description LIKE ? OR cat_no LIKE ?",
                              search_pattern, search_pattern, search_pattern, search_pattern
                            )
                            .limit(50)
                            .order(korean_product_name: :asc)
        else
          @products = Product.none
        end
        
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "product-results",
              partial: "admin/data_management/products/product_table",
              locals: { products: @products }
            )
          end
          format.html { render :index }
        end
      end
      
      def sync
        begin
          # 크롤러 DB 경로 찾기
          crawler_db_path = find_latest_crawler_db
          
          unless crawler_db_path && File.exist?(crawler_db_path)
            redirect_to admin_data_management_products_path, alert: "크롤러 DB를 찾을 수 없습니다."
            return
          end
          
          # 동기화 서비스 호출
          result = ProductSyncService.new(crawler_db_path).sync!
          
          redirect_to admin_data_management_products_path, 
                      notice: "동기화 완료: #{result[:imported]} 개 상품 가져옴, #{result[:updated]} 개 업데이트됨"
        rescue => e
          Rails.logger.error "Product sync failed: #{e.message}"
          redirect_to admin_data_management_products_path, 
                      alert: "동기화 실패: #{e.message}"
        end
      end

      private

      def set_product
        @product = Product.find(params[:id])
      end
      
      def find_latest_crawler_db
        # 크롤러 DB 경로들
        db_paths = [
          "/Users/macstudio/node/lab-shop-crawler/data/lab-shop.db",
          Dir.glob("/Users/macstudio/node/lab-shop-crawler/results/initial-setup/backup/*/lab-shop.db")
            .select { |f| File.size(f) > 100_000 } # 100KB 이상인 파일만
            .max_by { |f| File.mtime(f) }
        ].compact
        
        db_paths.find { |path| File.exist?(path) && File.size(path) > 0 }
      end
    end
  end
end