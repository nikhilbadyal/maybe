# frozen_string_literal: true

class Api::V1::ValuationsController < Api::V1::BaseController
  before_action -> { authorize_scope! :write }

  api :POST, "/accounts/:account_id/valuations", "Create a new valuation for an account"
  param :account_id, String, desc: "The ID of the account", required: true
  param :valuation, Hash, required: true do
    param :balance, [ Float, String ], desc: "The new balance of the account (accepts numbers or numeric strings)", required: true
    param :date, String, desc: "The date of the valuation (YYYY-MM-DD)", required: true
  end
  def create
    account = current_resource_owner.family.accounts.find(params[:account_id])

    # Validate account is eligible for manual valuations
    if account.linked?
      return render_json({
        error: "unprocessable_entity",
        message: "Cannot create manual valuations for linked accounts that sync data from external sources.",
        details: "This account is connected to #{account.plaid_account&.plaid_item&.institution_name || 'an external data provider'} and receives automatic balance updates."
      }, status: :unprocessable_entity)
    end

    unless account.active?
      return render_json({
        error: "unprocessable_entity",
        message: "Cannot create valuations for inactive accounts.",
        details: "Account status: #{account.status}"
      }, status: :unprocessable_entity)
    end

    begin
      balance = BigDecimal(valuation_params[:balance].to_s)
    rescue ArgumentError => e
      return render_json({
        error: "unprocessable_entity",
        message: "Invalid balance format. Please ensure balance is a valid number.",
        details: e.message
      }, status: :unprocessable_entity)
    end

    begin
      date = Date.iso8601(valuation_params[:date])
    rescue ArgumentError => e
      return render_json({
        error: "unprocessable_entity",
        message: "Invalid date format. Please use YYYY-MM-DD format.",
        details: e.message
      }, status: :unprocessable_entity)
    end

    # Validate date business rules
    if date > Date.current
      return render_json({
        error: "unprocessable_entity",
        message: "Cannot create valuations for future dates.",
        details: "Valuation date must be today (#{Date.current}) or earlier."
      }, status: :unprocessable_entity)
    end

    if date < account.start_date
      return render_json({
        error: "unprocessable_entity",
        message: "Cannot create valuations before account start date.",
        details: "Account start date: #{account.start_date}, provided date: #{date}"
      }, status: :unprocessable_entity)
    end

    result = account.create_reconciliation(balance: balance, date: date)

    if result.success?
      # Find the created/updated valuation entry
      valuation_entry = account.entries.valuations.find_by(date: date)

      render_json({
        success: true,
        message: "Valuation created successfully.",
        valuation: {
          id: valuation_entry.id,
          date: date.to_s,
          amount: result.new_balance,
          currency: account.currency,
          created_at: valuation_entry.created_at,
          updated_at: valuation_entry.updated_at
        },
        balance_changes: {
          old_balance: result.old_balance,
          new_balance: result.new_balance,
          old_cash_balance: result.old_cash_balance,
          new_cash_balance: result.new_cash_balance
        }
      }, status: :created)
    else
      render_json({
        error: "unprocessable_entity",
        message: "Failed to create valuation.",
        details: result.error_message
      }, status: :unprocessable_entity)
    end
  end

  private

    def valuation_params
      params.require(:valuation).permit(:balance, :date).tap do |p|
        p.require([ :balance, :date ])
      end
    end
end
