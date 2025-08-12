require "test_helper"

class BalanceSheet::AccountGroupTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "depository accounts group_by subtype yields expected keys" do
    # Prepare a mix of depository accounts with subtypes
    a1 = accounts(:connected) # subtype: checking
    a2 = accounts(:depository) # may not have subtype set

    # Ensure we have another depository account with a different subtype via fixtures
    a3 = accounts(:savings_depository)
    assert_equal "savings", a3.subtype

    # Ensure they belong to the same family context for balance sheet
    assert_equal @family.id, a1.family_id
    assert_equal @family.id, a2.family_id
    assert_equal @family.id, a3.family_id

    assets_group = @family.balance_sheet.assets
    depository_group = assets_group.account_groups.find { |g| g.key == "depository" }

    assert_not_nil depository_group, "Expected a depository (Cash) group in assets"

    # Emulate grouping as done in the view
    grouped_array = depository_group.grouped_accounts
    grouped = grouped_array.to_h

    assert grouped.key?("checking"), "Expected a 'checking' subtype group"
    assert grouped.key?("savings"), "Expected a 'savings' subtype group"
    assert grouped.key?(nil), "Expected a group for accounts with no subtype"

    # Verify sorting order: alphabetical by label/subtype, with nil last
    subtypes_order = grouped_array.map(&:first)
    assert_equal [ "checking", "savings", nil ], subtypes_order, "Subtypes are not sorted correctly."

    # The order assertion above verifies behavior; no need to re-implement the sorting comparator here.

    # Add an unknown subtype and assert it falls into the nil bucket alongside nil-subtype accounts
    unknown_subtype_account = @family.accounts.create!(
      name: "Unknown Subtype Account",
      balance: 100,
      currency: "USD",
      subtype: "some_random_subtype",
      accountable: Depository.new,
      accountable_type: "Depository",
      status: "active"
    )

    # Recompute groups after adding the unknown subtype.
    # Invalidate memoized balance sheet to ensure newly created account is included.
    @family.reset_balance_sheet!
    assets_group = @family.balance_sheet.assets
    depository_group = assets_group.account_groups.find { |g| g.key == "depository" }
    grouped_array = depository_group.grouped_accounts
    grouped = grouped_array.to_h

    nil_group_accounts = grouped[nil]
    assert_not_nil nil_group_accounts, "Expected a group for nil/unknown subtypes"
    assert_includes nil_group_accounts.map(&:account), unknown_subtype_account
    assert_includes nil_group_accounts.map(&:account), a2
  end
end
