# frozen_string_literal: true

class Api::V1::TransactionsController < Api::V1::BaseController
  include Pagy::Backend

  # ============================================================================
  # PARAMETER GROUPS FOR TRANSACTION FILTERING
  # ============================================================================

  def_param_group :transaction_filters do
    param :account_id, String, desc: "Filter by single account ID", required: false, example: "acc_123e4567"
    param :account_ids, Array, of: String, desc: "Filter by multiple account IDs", required: false, example: [ "acc_123e4567", "acc_789a0123" ]
    param :category_id, String, desc: "Filter by single category ID", required: false, example: "cat_123e4567"
    param :category_ids, Array, of: String, desc: "Filter by multiple category IDs", required: false, example: [ "cat_123e4567", "cat_789a0123" ]
    param :merchant_id, String, desc: "Filter by single merchant ID", required: false, example: "mer_123e4567"
    param :merchant_ids, Array, of: String, desc: "Filter by multiple merchant IDs", required: false, example: [ "mer_123e4567", "mer_789a0123" ]
    param_group :date_range_filter, Api::V1::BaseController
    param :min_amount, :decimal, desc: "Filter transactions >= this amount", required: false, example: 10.50
    param :max_amount, :decimal, desc: "Filter transactions <= this amount", required: false, example: 1000.00
    param :tag_ids, Array, of: String, desc: "Filter by tag IDs", required: false, example: [ "tag_123e4567" ]
    param :type, [ "income", "expense" ], desc: "Filter by transaction type", required: false, example: "expense"
    param :search, String, desc: "Search in transaction names, notes, or merchant names", required: false, example: "grocery"
  end

  def_param_group :transaction_create_params do
    param :transaction, Hash, desc: "Transaction details", required: true do
      param :account_id, String, desc: "Account ID for the transaction", required: true, example: "acc_123e4567"
      param :date, Date, desc: "Transaction date (YYYY-MM-DD)", required: true, example: "2024-01-15"
      param :amount, :decimal, desc: "Transaction amount", required: true, example: 25.50
      param :name, String, desc: "Transaction name/description", required: false, example: "Grocery shopping"
      param :description, String, desc: "Alternative to name field", required: false, example: "Weekly groceries at Whole Foods"
      param :notes, String, desc: "Additional notes", required: false, example: "Used cashback credit card"
      param :currency, String, desc: "Currency code (defaults to family currency)", required: false, example: "USD"
      param :category_id, String, desc: "Category ID", required: false, example: "cat_123e4567"
      param :merchant_id, String, desc: "Merchant ID", required: false, example: "mer_123e4567"
      param :nature, [ "income", "inflow", "expense", "outflow" ], desc: "Transaction nature (affects amount sign)", required: false, example: "expense"
      param :tag_ids, Array, of: String, desc: "Tag IDs to associate", required: false, example: [ "tag_123e4567" ]
    end
  end

  def_param_group :transaction_response do
    property :id, String, desc: "Transaction ID", example: "txn_123e4567"
    property :date, Date, desc: "Transaction date", example: "2024-01-15"
    property :name, String, desc: "Transaction name", example: "Grocery shopping"
    property :amount, :decimal, desc: "Transaction amount", example: 25.50
    property :currency, String, desc: "Currency code", example: "USD"
    property :notes, String, desc: "Additional notes", example: "Used cashback credit card"
    property :account, Hash, desc: "Associated account" do
      param_group :account_basic, Api::V1::BaseController
    end
    property :category, Hash, desc: "Associated category (if any)" do
      param_group :category_basic, Api::V1::BaseController
    end
    property :merchant, Hash, desc: "Associated merchant (if any)" do
      param_group :merchant_basic, Api::V1::BaseController
    end
    property :tags, Array, of: Hash, desc: "Associated tags" do
      param_group :tag_basic, Api::V1::BaseController
    end
    property :created_at, DateTime, desc: "Creation timestamp", example: "2024-01-15T10:30:00Z"
    property :updated_at, DateTime, desc: "Last update timestamp", example: "2024-01-20T14:45:00Z"
  end

  resource_description do
    short "Manage financial transactions"
    formats [ "json" ]
    api_version "v1"
    tags "transactions", "financial_data"
    description <<-EOS
      ## Transaction Management

      Manage all financial transactions including:
      - **Income**: Money coming into accounts (salary, refunds, etc.)
      - **Expenses**: Money going out of accounts (purchases, bills, etc.)
      - **Transfers**: Money moving between your accounts

      ### Transaction Types
      - `income/inflow`: Positive money flow (amount stored as negative)
      - `expense/outflow`: Negative money flow (amount stored as positive)

      ### Filtering & Search
      Filter transactions by date range, amount range, accounts, categories, merchants, tags, or search text.

      ### Pagination
      All list endpoints support pagination with configurable page size (max 100 items).
    EOS
    meta module: "Core API", priority: "high"
  end

  # Ensure proper scope authorization for read vs write access
  before_action :ensure_read_scope, only: [ :index, :show ]
  before_action :ensure_write_scope, only: [ :create, :update, :destroy ]
  before_action :set_transaction, only: [ :show, :update, :destroy ]

  api :GET, "/transactions", "List transactions with filtering and pagination"
  description <<-EOS
    Retrieve a paginated list of transactions with comprehensive filtering options.
    Results are ordered by date (newest first) and include all related data.
  EOS
  param_group :pagination_params, Api::V1::BaseController
  param_group :transaction_filters, Api::V1::TransactionsController
  tags "transactions", "list", "filtering"
  returns code: 200, desc: "Successfully retrieved transactions list" do
    property :transactions, array_of: Hash, desc: "Array of transaction objects" do
      param_group :transaction_response, Api::V1::TransactionsController
    end
    param_group :pagination_response, Api::V1::BaseController
  end
  example <<-EOS
    GET /api/v1/transactions?category_id=cat_groceries&start_date=2024-01-01&end_date=2024-01-31&page=1&per_page=10

    Response:
    {
      "transactions": [
        {
          "id": "txn_123e4567",
          "date": "2024-01-15",
          "name": "Whole Foods Market",
          "amount": 125.50,
          "currency": "USD",
          "notes": "Weekly grocery shopping",
          "account": {
            "id": "acc_123e4567",
            "name": "Chase Checking",
            "balance": 2500.00,
            "currency": "USD",
            "classification": "asset"
          },
          "category": {
            "id": "cat_groceries",
            "name": "Groceries"
          },
          "merchant": {
            "id": "mer_wholefoods",
            "name": "Whole Foods Market"
          },
          "tags": [
            {
              "id": "tag_essential",
              "name": "Essential"
            }
          ],
          "created_at": "2024-01-15T10:30:00Z",
          "updated_at": "2024-01-15T10:30:00Z"
        }
      ],
      "pagination": {
        "page": 1,
        "per_page": 10,
        "total_count": 45,
        "total_pages": 5
      }
    }
  EOS

  def index
    family = current_resource_owner.family
    transactions_query = family.transactions.visible

    # Apply filters
    transactions_query = apply_filters(transactions_query)

    # Apply search
    transactions_query = apply_search(transactions_query) if params[:search].present?

    # Include necessary associations for efficient queries
    transactions_query = transactions_query.includes(
      { entry: :account },
      :category, :merchant, :tags,
      transfer_as_outflow: { inflow_transaction: { entry: :account } },
      transfer_as_inflow: { outflow_transaction: { entry: :account } }
    ).reverse_chronological

    # Handle pagination with Pagy
    @pagy, @transactions = pagy(
      transactions_query,
      page: safe_page_param,
      limit: safe_per_page_param
    )

    # Make per_page available to the template
    @per_page = safe_per_page_param

    # Rails will automatically use app/views/api/v1/transactions/index.json.jbuilder
    render :index

  rescue => e
    Rails.logger.error "TransactionsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  api :GET, "/transactions/:id", "Retrieve a single transaction"
  param :id, String, desc: "Transaction ID", required: true, example: "txn_123e4567"
  tags "transactions", "details"
  returns code: 200, desc: "Successfully retrieved transaction" do
    param_group :transaction_response, Api::V1::TransactionsController
  end
  returns code: 404, desc: "Transaction not found"
  example <<-EOS
    GET /api/v1/transactions/txn_123e4567

    Response:
    {
      "id": "txn_123e4567",
      "date": "2024-01-15",
      "name": "Whole Foods Market",
      "amount": 125.50,
      "currency": "USD",
      "notes": "Weekly grocery shopping",
      "account": {
        "id": "acc_123e4567",
        "name": "Chase Checking",
        "balance": 2500.00,
        "currency": "USD",
        "classification": "asset"
      },
      "category": {
        "id": "cat_groceries",
        "name": "Groceries"
      },
      "merchant": {
        "id": "mer_wholefoods",
        "name": "Whole Foods Market"
      },
      "tags": [
        {
          "id": "tag_essential",
          "name": "Essential"
        }
      ],
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  EOS
  def show
    # Rails will automatically use app/views/api/v1/transactions/show.json.jbuilder
    render :show

  rescue => e
    Rails.logger.error "TransactionsController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  api :POST, "/transactions", "Create a new transaction"
  description <<-EOS
    Create a new financial transaction. The transaction will be automatically
    categorized if possible and associated with the specified account.
  EOS
  param_group :transaction_create_params, Api::V1::TransactionsController
  tags "transactions", "create"
  returns code: 201, desc: "Successfully created transaction" do
    param_group :transaction_response, Api::V1::TransactionsController
  end
  returns code: 422, desc: "Validation failed - invalid transaction data"
  example <<-EOS
    Request:
    {
      "transaction": {
        "account_id": "acc_123e4567",
        "date": "2024-01-15",
        "amount": 125.50,
        "name": "Whole Foods Market",
        "notes": "Weekly grocery shopping",
        "category_id": "cat_groceries",
        "merchant_id": "mer_wholefoods",
        "nature": "expense",
        "tag_ids": ["tag_essential"]
      }
    }

    Response:
    {
      "id": "txn_123e4567",
      "date": "2024-01-15",
      "name": "Whole Foods Market",
      "amount": 125.50,
      "currency": "USD",
      "notes": "Weekly grocery shopping",
      "account": {
        "id": "acc_123e4567",
        "name": "Chase Checking",
        "balance": 2374.50,
        "currency": "USD",
        "classification": "asset"
      },
      "category": {
        "id": "cat_groceries",
        "name": "Groceries"
      },
      "merchant": {
        "id": "mer_wholefoods",
        "name": "Whole Foods Market"
      },
      "tags": [
        {
          "id": "tag_essential",
          "name": "Essential"
        }
      ],
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  EOS
  def create
    family = current_resource_owner.family

    # Validate account_id is present
    unless transaction_params[:account_id].present?
      render json: {
        error: "validation_failed",
        message: "Account ID is required",
        errors: [ "Account ID is required" ]
      }, status: :unprocessable_entity
      return
    end

    account = family.accounts.find(transaction_params[:account_id])
    @entry = account.entries.new(entry_params_for_create)

    if @entry.save
      @entry.sync_account_later
      @entry.lock_saved_attributes!
      @entry.transaction.lock_attr!(:tag_ids) if @entry.transaction.tags.any?

      @transaction = @entry.transaction
      render :show, status: :created
    else
      render json: {
        error: "validation_failed",
        message: "Transaction could not be created",
        errors: @entry.errors.full_messages
      }, status: :unprocessable_entity
    end

  rescue => e
    Rails.logger.error "TransactionsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  api :PUT, "/transactions/:id", "Update an existing transaction"
  api :PATCH, "/transactions/:id", "Update an existing transaction"
  param :id, String, desc: "Transaction ID to update", required: true, example: "txn_123e4567"
  param :transaction, Hash, desc: "Transaction fields to update" do
    param :date, Date, desc: "New transaction date", required: false, example: "2024-01-16"
    param :amount, :decimal, desc: "New transaction amount", required: false, example: 150.00
    param :name, String, desc: "New transaction name", required: false, example: "Updated name"
    param :description, String, desc: "New description", required: false, example: "Updated description"
    param :notes, String, desc: "New notes", required: false, example: "Updated notes"
    param :currency, String, desc: "New currency", required: false, example: "EUR"
    param :category_id, String, desc: "New category ID", required: false, example: "cat_456e7890"
    param :merchant_id, String, desc: "New merchant ID", required: false, example: "mer_456e7890"
    param :nature, [ "income", "inflow", "expense", "outflow" ], desc: "New transaction nature", required: false, example: "income"
    param :tag_ids, Array, of: String, desc: "New tag IDs", required: false, example: [ "tag_456e7890" ]
  end
  tags "transactions", "update"
  returns code: 200, desc: "Successfully updated transaction" do
    param_group :transaction_response, Api::V1::TransactionsController
  end
  returns code: 404, desc: "Transaction not found"
  returns code: 422, desc: "Validation failed - invalid update data"
  def update
    if @entry.update(entry_params_for_update)
      @entry.sync_account_later
      @entry.lock_saved_attributes!
      @entry.transaction.lock_attr!(:tag_ids) if @entry.transaction.tags.any?

      @transaction = @entry.transaction
      render :show
    else
      render json: {
        error: "validation_failed",
        message: "Transaction could not be updated",
        errors: @entry.errors.full_messages
      }, status: :unprocessable_entity
    end

  rescue => e
    Rails.logger.error "TransactionsController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  api :DELETE, "/transactions/:id", "Delete a transaction"
  param :id, String, desc: "Transaction ID to delete", required: true, example: "txn_123e4567"
  tags "transactions", "delete"
  returns code: 200, desc: "Successfully deleted transaction"
  returns code: 404, desc: "Transaction not found"
  example <<-EOS
    DELETE /api/v1/transactions/txn_123e4567

    Response:
    {
      "message": "Transaction deleted successfully"
    }
  EOS
  def destroy
    @entry.destroy!
    @entry.sync_account_later

    render json: {
      message: "Transaction deleted successfully"
    }, status: :ok

  rescue => e
    Rails.logger.error "TransactionsController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  private

    def set_transaction
      family = current_resource_owner.family
      @transaction = family.transactions.find(params[:id])
      @entry = @transaction.entry
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Transaction not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def apply_filters(query)
      # Account filtering
      if params[:account_id].present?
        query = query.joins(:entry).where(entries: { account_id: params[:account_id] })
      end

      if params[:account_ids].present?
        account_ids = Array(params[:account_ids])
        query = query.joins(:entry).where(entries: { account_id: account_ids })
      end

      # Category filtering
      if params[:category_id].present?
        query = query.where(category_id: params[:category_id])
      end

      if params[:category_ids].present?
        category_ids = Array(params[:category_ids])
        query = query.where(category_id: category_ids)
      end

      # Merchant filtering
      if params[:merchant_id].present?
        query = query.where(merchant_id: params[:merchant_id])
      end

      if params[:merchant_ids].present?
        merchant_ids = Array(params[:merchant_ids])
        query = query.where(merchant_id: merchant_ids)
      end

      # Date range filtering
      if params[:start_date].present?
        query = query.joins(:entry).where("entries.date >= ?", Date.parse(params[:start_date]))
      end

      if params[:end_date].present?
        query = query.joins(:entry).where("entries.date <= ?", Date.parse(params[:end_date]))
      end

      # Amount filtering
      if params[:min_amount].present?
        min_amount = params[:min_amount].to_f
        query = query.joins(:entry).where("entries.amount >= ?", min_amount)
      end

      if params[:max_amount].present?
        max_amount = params[:max_amount].to_f
        query = query.joins(:entry).where("entries.amount <= ?", max_amount)
      end

      # Tag filtering
      if params[:tag_ids].present?
        tag_ids = Array(params[:tag_ids])
        query = query.joins(:tags).where(tags: { id: tag_ids })
      end

      # Transaction type filtering (income/expense)
      if params[:type].present?
        case params[:type].downcase
        when "income"
          query = query.joins(:entry).where("entries.amount < 0")
        when "expense"
          query = query.joins(:entry).where("entries.amount > 0")
        end
      end

      query
    end

    def apply_search(query)
      search_term = "%#{params[:search]}%"

      query.joins(:entry)
           .left_joins(:merchant)
           .where(
             "entries.name ILIKE ? OR entries.notes ILIKE ? OR merchants.name ILIKE ?",
             search_term, search_term, search_term
           )
    end

    def transaction_params
      params.require(:transaction).permit(
        :account_id, :date, :amount, :name, :description, :notes, :currency,
        :category_id, :merchant_id, :nature, tag_ids: []
      )
    end

    def entry_params_for_create
      entry_params = {
        name: transaction_params[:name] || transaction_params[:description],
        date: transaction_params[:date],
        amount: calculate_signed_amount,
        currency: transaction_params[:currency] || current_resource_owner.family.currency,
        notes: transaction_params[:notes],
        entryable_type: "Transaction",
        entryable_attributes: {
          category_id: transaction_params[:category_id],
          merchant_id: transaction_params[:merchant_id],
          tag_ids: transaction_params[:tag_ids] || []
        }
      }

      entry_params.compact
    end

    def entry_params_for_update
      entry_params = {
        name: transaction_params[:name] || transaction_params[:description],
        date: transaction_params[:date],
        notes: transaction_params[:notes],
        entryable_attributes: {
          id: @entry.entryable_id,
          category_id: transaction_params[:category_id],
          merchant_id: transaction_params[:merchant_id],
          tag_ids: transaction_params[:tag_ids]
        }.compact_blank
      }

      # Only update amount if provided
      if transaction_params[:amount].present?
        entry_params[:amount] = calculate_signed_amount
      end

      entry_params.compact
    end

    def calculate_signed_amount
      amount = transaction_params[:amount].to_f
      nature = transaction_params[:nature]

      case nature&.downcase
      when "income", "inflow"
        -amount.abs  # Income is negative
      when "expense", "outflow"
        amount.abs   # Expense is positive
      else
        amount       # Use as provided
      end
    end

    def safe_page_param
      page = params[:page].to_i
      page > 0 ? page : 1
    end

    def safe_per_page_param
      per_page = params[:per_page].to_i
      case per_page
      when 1..100
        per_page
      else
        25  # Default
      end
    end
end
