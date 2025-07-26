class AddFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :english_product_name, :string
    add_column :products, :manufacturer, :string
    add_column :products, :brand, :string
    add_column :products, :category1, :string
    add_column :products, :category2, :string
    add_column :products, :product_url, :string
  end
end
