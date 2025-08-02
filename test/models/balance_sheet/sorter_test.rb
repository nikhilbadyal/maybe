require "test_helper"

class BalanceSheet::SorterTest < ActiveSupport::TestCase
  test "returns correct order clause for name_asc" do
    sorter = BalanceSheet::Sorter.for("name_asc")
    assert_equal "accounts.name ASC", sorter.order_clause
  end

  test "returns correct order clause for name_desc" do
    sorter = BalanceSheet::Sorter.for("name_desc")
    assert_equal "accounts.name DESC", sorter.order_clause
  end

  test "returns correct order clause for balance_asc" do
    sorter = BalanceSheet::Sorter.for("balance_asc")
    assert_equal "converted_balance ASC", sorter.order_clause
  end

  test "returns correct order clause for balance_desc" do
    sorter = BalanceSheet::Sorter.for("balance_desc")
    assert_equal "converted_balance DESC", sorter.order_clause
  end

  test "defaults to name_asc for invalid sort key" do
    sorter = BalanceSheet::Sorter.for("invalid_sort")
    assert_equal "accounts.name ASC", sorter.order_clause
  end

  test "defaults to name_asc for nil sort key" do
    sorter = BalanceSheet::Sorter.for(nil)
    assert_equal "accounts.name ASC", sorter.order_clause
  end

  test "defaults to name_asc for empty string sort key" do
    sorter = BalanceSheet::Sorter.for("")
    assert_equal "accounts.name ASC", sorter.order_clause
  end

  test "available_options returns expected format" do
    options = BalanceSheet::Sorter.available_options

    # Should have 4 options
    assert_equal 4, options.length

    # Each option should be an array with [label, value]
    options.each do |option|
      assert_kind_of Array, option
      assert_equal 2, option.length
      assert_kind_of String, option[0] # label
      assert_kind_of String, option[1] # value
    end

    # Should contain all valid sort keys as values
    values = options.map(&:last)
    assert_equal %w[name_asc name_desc balance_asc balance_desc].sort, values.sort
  end

  test "available_options uses I18n translations" do
    options = BalanceSheet::Sorter.available_options

    # Find the name_asc option
    name_asc_option = options.find { |option| option[1] == "name_asc" }
    assert_not_nil name_asc_option

    # Should use I18n translation
    expected_label = I18n.t("balance_sheet_sorter.name_asc")
    assert_equal expected_label, name_asc_option[0]
  end

  test "available_options handles missing translations gracefully" do
    # Temporarily add a new sort option that doesn't have translation
    original_options = BalanceSheet::Sorter::SORT_OPTIONS.dup

    # Stub the constant to include an option without translation
    BalanceSheet::Sorter.stubs(:SORT_OPTIONS).returns(
      original_options.merge("test_sort" => "test_column ASC")
    )

    # Should not raise an error even if translation is missing
    assert_nothing_raised do
      options = BalanceSheet::Sorter.available_options
      assert_kind_of Array, options
    end
  end

  test "SORT_OPTIONS constant contains all expected keys" do
    expected_keys = %w[name_asc name_desc balance_asc balance_desc]
    assert_equal expected_keys.sort, BalanceSheet::Sorter::SORT_OPTIONS.keys.sort
  end

  test "DEFAULT_SORT constant is name_asc" do
    assert_equal "name_asc", BalanceSheet::Sorter::DEFAULT_SORT
  end
end
