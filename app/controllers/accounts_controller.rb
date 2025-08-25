class AccountsController < ApplicationController
  before_action :set_account, only: %i[sync sparkline toggle_active show destroy purge_transactions]
  include Periodable

  def index
    @manual_accounts = family.accounts.manual.alphabetically
    @plaid_items = family.plaid_items.ordered

    render layout: "settings"
  end

  def show
    @chart_view = params[:chart_view] || "balance"
    @tab = params[:tab]
    @q = params.fetch(:q, {}).permit(:search)
    entries = @account.entries.search(@q).reverse_chronological

    @pagy, @entries = pagy(entries, limit: params[:per_page] || "50")

    @activity_feed_data = Account::ActivityFeedData.new(@account, @entries)
  end

  def sync
    unless @account.syncing?
      @account.sync_later
    end

    redirect_to account_path(@account)
  end

  def sync_all
    unless family.syncing?
      family.sync_later
    end

    redirect_back_or_to accounts_path, notice: "Syncing all accounts..."
  end

  def sparkline
    etag_key = @account.family.build_cache_key("#{@account.id}_sparkline", invalidate_on_data_updates: true)

    # Short-circuit with 304 Not Modified when the client already has the latest version.
    # We defer the expensive series computation until we know the content is stale.
    if stale?(etag: etag_key, last_modified: @account.family.latest_sync_completed_at)
      @sparkline_series = @account.sparkline_series
      render layout: false
    end
  end

  def toggle_active
    if @account.active?
      @account.disable!
    elsif @account.disabled?
      @account.enable!
    end
    redirect_to accounts_path
  end

  def destroy
    if @account.linked?
      redirect_to account_path(@account), alert: "Cannot delete a linked account"
    else
      @account.destroy_later
      redirect_to accounts_path, notice: "Account scheduled for deletion"
    end
  end

  def purge_transactions
    if @account.linked?
      return redirect_to account_path(@account), alert: "Cannot purge a linked account"
    end

    begin
      deleted_count = @account.purge_entries_except_opening_anchor!
      @account.sync_later
      redirect_to account_path(@account), notice: "Purged #{deleted_count} transaction#{deleted_count == 1 ? '' : 's'}"
    rescue StandardError => e
      Rails.logger.error("Failed to purge transactions for account #{@account.id}: #{e.message}")
      redirect_to account_path(@account), alert: "An error occurred while purging transactions."
    end
  end

  private
    def family
      Current.family
    end

    def set_account
      @account = family.accounts.find(params[:id])
    end
end
