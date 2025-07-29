# frozen_string_literal: true

class Api::V1::AccountsController < Api::V1::BaseController
  include Pagy::Backend

  resource_description do
    short "Manage user financial accounts"
    formats [ "json" ]
    api_version "v1"
    tags "accounts", "financial_data"
    description <<-EOS
      ## Account Management

      Manage all types of financial accounts including:
      - **Assets**: Checking, Savings, Investment, Property, Vehicles, Crypto
      - **Liabilities**: Credit Cards, Loans, Mortgages

      All endpoints support pagination and return accounts belonging to the authenticated user's family.

      ### Account Classifications
      - `asset`: Accounts that hold value (checking, savings, investments)
      - `liability`: Accounts that represent debt (credit cards, loans)
    EOS
    meta module: "Core API", priority: "high"
  end

  # Ensure proper scope authorization for read access
  before_action :ensure_read_scope

  api :GET, "/accounts", "List all user accounts with pagination"
  description <<-EOS
    Retrieve a paginated list of all financial accounts belonging to the authenticated user's family.
    Accounts are returned in alphabetical order by name.
  EOS
  param_group :pagination_params, Api::V1::BaseController
  tags "accounts", "list"
  returns code: 200, desc: "Successfully retrieved accounts list" do
    property :accounts, array_of: Hash, desc: "Array of account objects" do
      param_group :account_basic, Api::V1::BaseController
      property :created_at, DateTime, desc: "Account creation timestamp", example: "2024-01-15T10:30:00Z"
      property :updated_at, DateTime, desc: "Last update timestamp", example: "2024-01-20T14:45:00Z"
    end
    param_group :pagination_response, Api::V1::BaseController
  end

  example <<-EOS
    {
      "accounts": [
        {
          "id": "acc_123e4567",
          "name": "Chase Checking",
          "balance": 1250.50,
          "currency": "USD",
          "classification": "asset",
          "created_at": "2024-01-15T10:30:00Z",
          "updated_at": "2024-01-20T14:45:00Z"
        },
        {
          "id": "acc_789a0123",#{' '}
          "name": "Chase Credit Card",
          "balance": -850.25,
          "currency": "USD",
          "classification": "liability",
          "created_at": "2024-01-16T11:20:00Z",
          "updated_at": "2024-01-22T09:15:00Z"
        }
      ],
      "pagination": {
        "page": 1,
        "per_page": 25,
        "total_count": 12,
        "total_pages": 1
      }
    }
  EOS

  def index
    # Test with Pagy pagination
    family = current_resource_owner.family
    accounts_query = family.accounts.visible.alphabetically

    # Handle pagination with Pagy
    @pagy, @accounts = pagy(
      accounts_query,
      page: safe_page_param,
      limit: safe_per_page_param
    )

    @per_page = safe_per_page_param

    # Rails will automatically use app/views/api/v1/accounts/index.json.jbuilder
    render :index
  rescue => e
    Rails.logger.error "AccountsController error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def safe_page_param
      page = params[:page].to_i
      page > 0 ? page : 1
    end

    def safe_per_page_param
      per_page = params[:per_page].to_i

      # Default to 25, max 100
      case per_page
      when 1..100
        per_page
      else
        25
      end
    end
end
