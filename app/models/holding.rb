class Holding < ApplicationRecord
  include Monetizable, Gapfillable

  monetize :amount

  belongs_to :account
  belongs_to :security

  validates :qty, :currency, :date, :price, :amount, presence: true
  validates :qty, :price, :amount, numericality: { greater_than_or_equal_to: 0 }

  scope :chronological, -> { order(:date) }
  scope :for, ->(security) { where(security_id: security).order(:date) }

  delegate :ticker, to: :security

  def name
    security.name || ticker
  end

  def weight
    return nil unless amount
    return 0 if amount.zero?

    account.balance.zero? ? 1 : amount / account.balance * 100
  end

  # Basic approximation of cost-basis
  def avg_cost
    trades = account.trades.where(security_id: security_id).order(:created_at)

    total_quantity = 0.0
    cost_basis = 0.0

    trades.each do |trade|
      qty = trade.qty
      price = trade.price

      if qty > 0
        # Buy order: increase cost basis and total quantity
        cost_basis += qty * price
        total_quantity += qty
      elsif qty < 0
        sell_qty = qty.abs

        if sell_qty <= total_quantity
          # Sell order: reduce cost basis proportionally
          avg_price = cost_basis / total_quantity
          cost_basis -= sell_qty * avg_price
          total_quantity -= sell_qty
        else
          raise "Sell quantity exceeds holdings! Invalid trade data."
        end
      end
    end

    # Calculate average cost
    avg_cost = total_quantity > 0 ? (cost_basis / total_quantity) : 0
    Money.new(avg_cost, currency)
  end

  def trend
    @trend ||= calculate_trend
  end

  def trades
    account.entries.where(entryable: account.trades.where(security: security)).reverse_chronological
  end

  def destroy_holding_and_entries!
    transaction do
      account.entries.where(entryable: account.trades.where(security: security)).destroy_all
      destroy
    end

    account.sync_later
  end

  private
    def calculate_trend
      return nil unless amount_money

      start_amount = qty * avg_cost

      Trend.new \
        current: amount_money,
        previous: start_amount
    end
end
