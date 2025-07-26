# frozen_string_literal: true

require 'sqlite3'

class ProductSyncService
  def initialize(crawler_db_path)
    @crawler_db_path = crawler_db_path
    @imported_count = 0
    @updated_count = 0
  end
  
  def sync!
    Rails.logger.info "Starting product sync from: #{@crawler_db_path}"
    
    # 크롤러 DB 연결
    crawler_db = SQLite3::Database.new(@crawler_db_path)
    crawler_db.results_as_hash = true
    
    # 트랜잭션으로 처리
    Product.transaction do
      # 부모 상품 먼저 동기화
      sync_parent_products(crawler_db)
      
      # 자식 상품 동기화
      sync_child_products(crawler_db)
    end
    
    Rails.logger.info "Product sync completed: #{@imported_count} imported, #{@updated_count} updated"
    
    { imported: @imported_count, updated: @updated_count }
  ensure
    crawler_db&.close
  end
  
  private
  
  def sync_parent_products(crawler_db)
    parents = crawler_db.execute("SELECT * FROM parents")
    
    parents.each do |parent_data|
      product = Product.find_or_initialize_by(
        new_catalog_number: parent_data['NewCatalogNumber']
      )
      
      was_new = product.new_record?
      
      product.assign_attributes(
        korean_product_name: parent_data['상품명'] || "제품명 없음",
        description: build_description(parent_data),
        unit: extract_unit(parent_data['상품명']),
        price: 0, # 가격은 children 테이블에서 가져와야 함
        stock_quantity: 0,
        cat_no: parent_data['g_no'],
        image_path: parent_data['상품이미지URL'],
        parent_product_id: nil
      )
      
      if product.save
        was_new ? @imported_count += 1 : @updated_count += 1
      end
    end
  end
  
  def sync_child_products(crawler_db)
    children = crawler_db.execute("SELECT * FROM children")
    
    children.each do |child_data|
      # 부모 상품 찾기
      parent = Product.find_by(new_catalog_number: child_data['parent_NewCatalogNumber'])
      next unless parent
      
      # 자식 상품이 이미 있는 경우 처리
      if child_data['NewCatalogNumber'] == parent.new_catalog_number
        # 부모 상품의 가격과 재고 업데이트
        parent.update(
          price: child_data['가격'].to_f,
          stock_quantity: parse_stock(child_data['재고'])
        )
        next
      end
      
      # 자식 상품 생성/업데이트
      child_product = Product.find_or_initialize_by(
        new_catalog_number: child_data['NewCatalogNumber']
      )
      
      was_new = child_product.new_record?
      
      child_product.assign_attributes(
        korean_product_name: child_data['상품명'] || parent.korean_product_name,
        description: child_data['상품설명'],
        unit: child_data['단위'] || "EA",
        price: child_data['가격'].to_f,
        stock_quantity: parse_stock(child_data['재고']),
        cat_no: child_data['Cat. No'],
        image_path: parent.image_path,
        parent_product_id: parent.id
      )
      
      if child_product.save
        was_new ? @imported_count += 1 : @updated_count += 1
      end
    end
  end
  
  def build_description(parent_data)
    parts = []
    parts << parent_data['제품설명'] if parent_data['제품설명'].present?
    parts << "주요특징: #{parent_data['주요특징']}" if parent_data['주요특징'].present?
    parts << "스펙: #{parent_data['스펙']}" if parent_data['스펙'].present?
    parts.join("\n\n")
  end
  
  def extract_unit(product_name)
    # 상품명에서 단위 추출 (예: "제품명, 100ml" -> "100ml")
    return "EA" if product_name.nil?
    
    match = product_name.match(/,\s*(\d+\s*\w+)$/)
    match ? match[1] : "EA"
  end
  
  def parse_stock(stock_str)
    return 0 if stock_str.nil? || stock_str.empty?
    
    case stock_str
    when /재고문의/i, /품절/i
      0
    when /(\d+)/
      $1.to_i
    else
      0
    end
  end
end