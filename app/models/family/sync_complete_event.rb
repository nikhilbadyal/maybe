class Family::SyncCompleteEvent
  attr_reader :family

  def initialize(family)
    @family = family
  end

  def broadcast
    family.broadcast_replace(
      target: "balance-sheet",
      partial: "pages/dashboard/balance_sheet",
      locals: { balance_sheet: family.balance_sheet }
    )

    family.broadcast_replace(
      target: "net-worth-chart",
      partial: "pages/dashboard/net_worth_chart",
      locals: { balance_sheet: family.balance_sheet, period: Period.last_30_days }
    )

    # Update sync all button on accounts page
    family.broadcast_replace(
      target: "sync_all_button",
      partial: "accounts/sync_all_button",
      locals: { manual_accounts: family.accounts.manual.alphabetically, plaid_items: family.plaid_items.ordered }
    )
  end
end
