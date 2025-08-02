require "test_helper"

class BalanceSheet::AccountTotalsTest < ActiveSupport::TestCase
  def setup
    @family = families(:dylan_family)
    @sync_status_monitor = mock("sync_status_monitor")
    @sync_status_monitor.stubs(:account_syncing?).returns(false)
    @user = users(:family_admin)
    Current.session = @user.sessions.create!
  end

  test "uses current user's balance_sheet_sort preference by default" do
    @user.update!(balance_sheet_sort: "balance_desc")

    account_totals = BalanceSheet::AccountTotals.new(@family, sync_status_monitor: @sync_status_monitor)

    # Mock the cache and visible_accounts to test the order clause
    cache_key = account_totals.send(:cache_key)
    assert_includes cache_key, "balance_desc"
  end

  test "allows overriding sort preference with sort_by parameter" do
    @user.update!(balance_sheet_sort: "name_asc")

    account_totals = BalanceSheet::AccountTotals.new(
      @family,
      sync_status_monitor: @sync_status_monitor,
      sort_by: "balance_desc"
    )

    cache_key = account_totals.send(:cache_key)
    assert_includes cache_key, "balance_desc"
  end

  test "includes sort preference in cache key" do
    account_totals = BalanceSheet::AccountTotals.new(
      @family,
      sync_status_monitor: @sync_status_monitor,
      sort_by: "name_desc"
    )

    cache_key = account_totals.send(:cache_key)
    assert_includes cache_key, "balance_sheet_account_rows_name_desc"
  end

  test "uses correct sort order in query" do
    # Create some accounts for testing
    account1 = @family.accounts.create!(
      name: "Alpha Account",
      balance: 100,
      currency: "USD",
      accountable: Depository.new
    )
    account2 = @family.accounts.create!(
      name: "Beta Account",
      balance: 200,
      currency: "USD",
      accountable: Depository.new
    )

    # Test name ascending sort
    account_totals = BalanceSheet::AccountTotals.new(
      @family,
      sync_status_monitor: @sync_status_monitor,
      sort_by: "name_asc"
    )

    # Mock the sorter to verify it's called with correct key
    BalanceSheet::Sorter.expects(:for).with("name_asc").returns(
      OpenStruct.new(order_clause: "accounts.name ASC")
    )

    # Clear cache to force query execution
    Rails.cache.clear

    # This will trigger the query method which uses the sorter
    account_totals.asset_accounts
  end

  test "filters accounts by classification after sorting" do
    # Mock accounts with different classifications
    asset_account = OpenStruct.new(
      classification: "asset",
      name: "Asset Account",
      converted_balance: 100
    )
    liability_account = OpenStruct.new(
      classification: "liability",
      name: "Liability Account",
      converted_balance: 50
    )

    account_totals = BalanceSheet::AccountTotals.new(
      @family,
      sync_status_monitor: @sync_status_monitor,
      sort_by: "name_asc"
    )

    # Mock the query to return our test accounts
    account_totals.stubs(:query).returns([ asset_account, liability_account ])

    assets = account_totals.asset_accounts
    liabilities = account_totals.liability_accounts

    assert_equal 1, assets.length
    assert_equal "asset", assets.first.classification

    assert_equal 1, liabilities.length
    assert_equal "liability", liabilities.first.classification
  end

  test "handles nil sort_by gracefully" do
    account_totals = BalanceSheet::AccountTotals.new(
      @family,
      sync_status_monitor: @sync_status_monitor,
      sort_by: nil
    )

    # Should default to user's preference
    cache_key = account_totals.send(:cache_key)
    assert_includes cache_key, @user.balance_sheet_sort
  end

  test "handles nil Current.user gracefully" do
    # Temporarily clear the current session
    original_session = Current.session
    Current.session = nil

    account_totals = BalanceSheet::AccountTotals.new(
      @family,
      sync_status_monitor: @sync_status_monitor,
      sort_by: nil
    )

    # Should default to name_asc when no user is present
    cache_key = account_totals.send(:cache_key)
    assert_includes cache_key, "name_asc"
  ensure
    # Restore the session
    Current.session = original_session
  end

  test "account rows maintain sort order from query" do
    # Create test accounts in specific order
    account_a = @family.accounts.create!(
      name: "AAAA Test Account",
      balance: 300,
      currency: "USD",
      accountable: Depository.new
    )
    account_b = @family.accounts.create!(
      name: "BBBB Test Account",
      balance: 100,
      currency: "USD",
      accountable: Depository.new
    )

    account_totals = BalanceSheet::AccountTotals.new(
      @family,
      sync_status_monitor: @sync_status_monitor,
      sort_by: "name_asc"
    )

    # Clear cache to ensure fresh query
    Rails.cache.clear

    asset_accounts = account_totals.asset_accounts

    # Find our test accounts in the results
    test_accounts = asset_accounts.select { |acc| acc.name.include?("Test Account") }

    # Should maintain alphabetical order by name for our test accounts
    assert_equal "AAAA Test Account", test_accounts.first.name if test_accounts.any?
    assert_equal "BBBB Test Account", test_accounts.last.name if test_accounts.length > 1
  end
end
