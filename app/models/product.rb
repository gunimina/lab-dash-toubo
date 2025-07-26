# frozen_string_literal: true

class Product < ApplicationRecord
  # Associations
  belongs_to :parent_product, class_name: 'Product', optional: true
  has_many :child_products, class_name: 'Product', foreign_key: 'parent_product_id'
  
  # Validations
  validates :korean_product_name, presence: true
  
  # Scopes
  scope :parent_products, -> { where(parent_product_id: nil) }
  scope :child_products, -> { where.not(parent_product_id: nil) }
  
  # Pagination
  paginates_per 20
  
  # Methods
  def parent?
    parent_product_id.nil?
  end
  
  def has_children?
    child_products.exists?
  end
  
  def image_url
    # 이미지 URL 로직 추가
    image_path.presence || '/images/no-image.png'
  end
  
  # 부모 상품의 대표 자식 상품 (첫 번째 자식)
  def representative_child
    @representative_child ||= child_products.first
  end
  
  # 표시용 가격 (자식 상품의 가격)
  def display_price
    if parent?
      representative_child&.price || price
    else
      price
    end
  end
  
  # 표시용 재고 (자식 상품의 재고)
  def display_stock_quantity
    if parent?
      representative_child&.stock_quantity || stock_quantity
    else
      stock_quantity
    end
  end
  
  # 표시용 단위 (자식 상품의 단위)
  def display_unit
    if parent?
      representative_child&.unit || unit
    else
      unit
    end
  end
  
  # 표시용 설명 (자식 상품의 설명 포함)
  def display_description
    if parent? && representative_child
      representative_child.description || description
    else
      description
    end
  end
end