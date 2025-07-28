class AddUseDataProviderToFamilies < ActiveRecord::Migration[7.2]
  def change
    add_column :families, :use_data_provider, :boolean, default: true, null: false
  end
end
