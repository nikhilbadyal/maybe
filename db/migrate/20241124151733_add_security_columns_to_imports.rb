class AddSecurityColumnsToImports < ActiveRecord::Migration[7.2]
  def change
    add_column :imports, :country_code_col_label, :string
    add_column :imports, :exchange_mic_col_label, :string
    add_column :imports, :exchange_acronym_col_label, :string
  end
end
