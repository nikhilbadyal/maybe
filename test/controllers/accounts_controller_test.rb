require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper
  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "should get index" do
    get accounts_url
    assert_response :success
  end

  test "should get show" do
    get account_url(@account)
    assert_response :success
  end

  test "should sync account" do
    post sync_account_url(@account)
    assert_redirected_to account_url(@account)
  end

  test "should get sparkline" do
    get sparkline_account_url(@account)
    assert_response :success
  end

  test "destroys account" do
    delete account_url(@account)
    assert_redirected_to accounts_path
    assert_enqueued_with job: DestroyJob
    assert_equal "Account scheduled for deletion", flash[:notice]
  end

  test "purge transactions removes all entries except opening anchor and clears balances/holdings" do
    # Seed: opening anchor valuation and two transactions
    create_valuation(account: @account, kind: "opening_anchor", amount: 5000, date: 10.days.ago.to_date)
    create_transaction(account: @account, name: "T1", amount: 100, date: 5.days.ago.to_date)
    create_transaction(account: @account, name: "T2", amount: -50, date: 3.days.ago.to_date)

    # Create a balance and a holding record to ensure they are cleared
    Balance.create!(account: @account, date: Date.current, balance: 1000, flows_factor: 1)

    security = securities(:aapl)
    Holding.create!(account: @account, security: security, date: Date.current, qty: 1, price: 100, amount: 100, currency: @account.currency)

    assert_operator @account.entries.count, :>=, 3
    assert_equal 1, @account.valuations.opening_anchor.count
    assert_operator @account.balances.count, :>=, 1
    assert_operator @account.holdings.count, :>=, 1

    initial_entries_count = @account.entries.count
    assert_enqueued_with job: SyncJob do
      delete purge_transactions_account_url(@account)
    end

    assert_redirected_to account_url(@account)
    purged_count = initial_entries_count - 1 # Only opening anchor remains
    assert_match /Purged #{purged_count} transactions?/, flash[:notice]
    assert_equal purged_count, initial_entries_count - @account.reload.entries.count

    @account.reload
    # Only opening anchor remains
    remaining_entries = @account.entries.to_a
    assert_equal 1, remaining_entries.size
    assert remaining_entries.first.valuation?
    assert_equal "opening_anchor", remaining_entries.first.entryable.kind

    # Balances and holdings cleared
    assert_equal 0, @account.balances.count
    assert_equal 0, @account.holdings.count
  end

  test "purge transactions is blocked for linked accounts" do
    linked = accounts(:connected)
    assert linked.linked?

    delete purge_transactions_account_url(linked)

    assert_redirected_to account_url(linked)
    assert_equal "Cannot purge a linked account", flash[:alert]
  end
end
