class BalanceSheet::Sorter
  SORT_OPTIONS = {
    "name_asc" => "accounts.name ASC",
    "name_desc" => "accounts.name DESC",
    "balance_asc" => "converted_balance ASC",
    "balance_desc" => "converted_balance DESC"
  }.freeze

  DEFAULT_SORT = "name_asc"

  def self.for(key)
    new(key)
  end

  def self.available_options
    SORT_OPTIONS.keys.map do |key|
      [ I18n.t("balance_sheet_sorter.#{key}"), key ]
    end
  end

  def initialize(key)
    @key = key&.presence || DEFAULT_SORT
  end

  def order_clause
    SORT_OPTIONS.fetch(key, SORT_OPTIONS[DEFAULT_SORT])
  end

  private
    attr_reader :key
end
