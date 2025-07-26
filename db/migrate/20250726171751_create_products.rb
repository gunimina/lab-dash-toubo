class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :new_catalog_number
      t.string :korean_product_name
      t.text :description
      t.string :unit
      t.decimal :price, precision: 10, scale: 2
      t.integer :stock_quantity
      t.string :cat_no
      t.string :image_path
      t.integer :parent_product_id
      
      t.timestamps
    end
    
    add_index :products, :new_catalog_number
    add_index :products, :korean_product_name
    add_index :products, :cat_no
    add_index :products, :parent_product_id
  end
end
