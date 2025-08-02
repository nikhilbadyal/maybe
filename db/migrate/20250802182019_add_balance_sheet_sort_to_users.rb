class AddBalanceSheetSortToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :balance_sheet_sort, :string, default: "name_asc", null: false
  end
end
