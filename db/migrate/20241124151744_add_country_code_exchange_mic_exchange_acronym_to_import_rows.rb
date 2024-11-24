class AddCountryCodeExchangeMicExchangeAcronymToImportRows < ActiveRecord::Migration[7.2]
  def change
    add_column :import_rows, :country_code, :string
    add_column :import_rows, :exchange_mic, :string
    add_column :import_rows, :exchange_acronym, :string
  end
end
