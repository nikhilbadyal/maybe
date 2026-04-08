module Account::Reconcileable
  extend ActiveSupport::Concern

  # Creates a new reconciliation (valuation) entry for the account.
  # Accepts an optional `notes` parameter that will be stored on the entry.
  def create_reconciliation(balance:, date:, dry_run: false, notes: nil)
    result = reconciliation_manager.reconcile_balance(balance: balance, date: date, dry_run: dry_run, notes: notes)
    sync_later if result.success? && !dry_run
    result
  end

  # Updates an existing reconciliation entry with new balance/date/notes values.
  def update_reconciliation(existing_valuation_entry, balance:, date:, dry_run: false, notes: nil)
    result = reconciliation_manager.reconcile_balance(balance: balance, date: date, dry_run: dry_run, existing_valuation_entry: existing_valuation_entry, notes: notes)
    sync_later if result.success? && !dry_run
    result
  end

  private
    def reconciliation_manager
      @reconciliation_manager ||= Account::ReconciliationManager.new(self)
    end
end
