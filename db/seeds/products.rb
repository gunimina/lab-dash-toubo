# Sample product data for testing
puts "Creating sample products..."

# Create parent products
20.times do |i|
  product = Product.create!(
    new_catalog_number: "NC-#{1000 + i}",
    korean_product_name: "테스트 제품 #{i + 1}",
    description: "이것은 테스트 제품 #{i + 1}의 상세 설명입니다. 다양한 용도로 사용할 수 있는 고품질 제품입니다.",
    unit: ["EA", "Box", "Pack", "Set"].sample,
    price: rand(10000..500000),
    stock_quantity: rand(0..100),
    cat_no: "CAT-#{2000 + i}",
    image_path: nil,
    parent_product_id: nil
  )
  
  # Create child products for some parent products
  if i.even? && i < 10
    rand(2..5).times do |j|
      Product.create!(
        new_catalog_number: "#{product.new_catalog_number}-#{j + 1}",
        korean_product_name: "#{product.korean_product_name} - 옵션 #{j + 1}",
        description: "#{product.description} (옵션 #{j + 1})",
        unit: product.unit,
        price: product.price * (0.8 + rand * 0.4),
        stock_quantity: rand(0..50),
        cat_no: "#{product.cat_no}-#{j + 1}",
        image_path: nil,
        parent_product_id: product.id
      )
    end
  end
end

puts "Created #{Product.count} products (#{Product.parent_products.count} parent products)"