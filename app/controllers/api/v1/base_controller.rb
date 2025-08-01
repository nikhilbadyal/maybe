# frozen_string_literal: true

class Api::V1::BaseController < ApplicationController
  include Doorkeeper::Rails::Helpers

  # ============================================================================
  # PARAMETER GROUPS FOR REUSE ACROSS API CONTROLLERS
  # ============================================================================

  def_param_group :device_info do
    param :device, Hash, desc: "Device information for OAuth token creation" do
      param :device_id, String, desc: "Unique device identifier", required: true
      param :device_name, String, desc: "Name of the device (e.g., 'My iPhone')", required: true
      param :device_type, String, desc: "Type of device (e.g., 'iOS', 'Android')", required: true
      param :os_version, String, desc: "Operating system version", required: true
      param :app_version, String, desc: "Application version", required: true
    end
  end

  def_param_group :pagination_params do
    param :page, String, desc: "Page number for pagination (default: 1)", required: false, example: "1"
    param :per_page, String, desc: "Number of items per page (max 100, default 25)", required: false, example: "25"
  end

  def_param_group :date_range_filter do
    param :start_date, String, desc: "Filter from this date (YYYY-MM-DD)", required: false, example: "2024-01-01"
    param :end_date, String, desc: "Filter to this date (YYYY-MM-DD)", required: false, example: "2024-12-31"
  end

  def_param_group :pagination_response do
    property :pagination, Hash, desc: "Pagination metadata" do
      property :page, :number, desc: "Current page number", example: 1
      property :per_page, :number, desc: "Number of items per page", example: 25
      property :total_count, :number, desc: "Total number of items", example: 150
      property :total_pages, :number, desc: "Total number of pages", example: 6
    end
  end

  def_param_group :user_response do
    property :user, Hash, desc: "User details" do
      property :id, String, desc: "User ID", example: "123e4567-e89b-12d3-a456-426614174000"
      property :email, String, desc: "User email", example: "user@example.com"
      property :first_name, String, desc: "User first name", example: "John"
      property :last_name, String, desc: "User last name", example: "Doe"
    end
  end

  def_param_group :oauth_token_response do
    property :access_token, String, desc: "OAuth access token", example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    property :refresh_token, String, desc: "OAuth refresh token", example: "def50200abc123..."
    property :token_type, String, desc: "Token type", example: "Bearer"
    property :expires_in, Integer, desc: "Access token expiration in seconds", example: 2592000
    property :created_at, Integer, desc: "Access token creation timestamp", example: 1640995200
  end

  def_param_group :account_basic do
    property :id, String, desc: "Account ID", example: "acc_123e4567"
    property :name, String, desc: "Account name", example: "Chase Checking"
    property :balance, Float, desc: "Current balance", example: 1250.50
    property :currency, String, desc: "Currency code", example: "USD"
    property :classification, String, desc: "Account classification", example: "asset"
  end

  def_param_group :category_basic do
    property :id, String, desc: "Category ID", example: "cat_123e4567"
    property :name, String, desc: "Category name", example: "Groceries"
  end

  def_param_group :merchant_basic do
    property :id, String, desc: "Merchant ID", example: "mer_123e4567"
    property :name, String, desc: "Merchant name", example: "Whole Foods"
  end

  def_param_group :tag_basic do
    property :id, String, desc: "Tag ID", example: "tag_123e4567"
    property :name, String, desc: "Tag name", example: "business"
  end

  # ============================================================================
  # COMMON ERROR RESPONSES
  # ============================================================================



  # ============================================================================
  # RESOURCE DESCRIPTION
  # ============================================================================

  resource_description do
    short "Base API controller with common functionality"
    formats [ "json" ]
    api_version "v1"
    description <<-EOS
      Base controller for all Maybe API endpoints.

      == Authentication
      All endpoints require authentication via:
      - OAuth2 Bearer token in Authorization header: `Authorization: Bearer <token>`
      - API Key in X-Api-Key header: `X-Api-Key: <key>`

      == Rate Limiting
      API key requests are rate limited based on the key's configuration.
      OAuth requests are not rate limited.

      == Error Handling
      All endpoints return consistent error responses with appropriate HTTP status codes.

      == Scopes
      - `read`: Read-only access to user data
      - `read_write`: Full access to user data (includes read access)
    EOS
    meta author: { name: "Maybe Team" }
  end

  # Skip regular session-based authentication for API
  skip_authentication

  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token

  # Skip onboarding requirements for API endpoints
  skip_before_action :require_onboarding_and_upgrade

  # Force JSON format for all API requests
  before_action :force_json_format
  # Use our custom authentication that supports both OAuth and API keys
  before_action :authenticate_request!
  before_action :check_api_key_rate_limit
  before_action :log_api_access



  # Override Doorkeeper's default behavior to return JSON instead of redirecting
  def doorkeeper_unauthorized_render_options(error: nil)
    { json: { error: "unauthorized", message: "Access token is invalid, expired, or missing" } }
  end

  # Error handling for common API errors
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from Doorkeeper::Errors::DoorkeeperError, with: :handle_unauthorized
  rescue_from ActionController::ParameterMissing, with: :handle_bad_request

  private

    # Force JSON format for all API requests
    def force_json_format
      request.format = :json
    end

    # Authenticate using either OAuth or API key
    def authenticate_request!
      return if authenticate_oauth
      return if authenticate_api_key
      render_unauthorized unless performed?
    end

    # Try OAuth authentication first
    def authenticate_oauth
      return false unless request.headers["Authorization"].present?

      # Manually verify the token (bypassing doorkeeper_authorize! which had scope issues)
      token_string = request.authorization&.split(" ")&.last
      access_token = Doorkeeper::AccessToken.by_token(token_string)

      # Check token validity and scope (read_write includes read access)
      has_sufficient_scope = access_token&.scopes&.include?("read") || access_token&.scopes&.include?("read_write")

      unless access_token && !access_token.expired? && has_sufficient_scope
        render_json({ error: "unauthorized", message: "Access token is invalid, expired, or missing required scope" }, status: :unauthorized)
        return false
      end

      # Set the doorkeeper_token for compatibility
      @_doorkeeper_token = access_token

      if doorkeeper_token&.resource_owner_id
        @current_user = User.find_by(id: doorkeeper_token.resource_owner_id)

        # If user doesn't exist, the token is invalid (user was deleted)
        unless @current_user
          Rails.logger.warn "API OAuth Token Invalid: Access token resource_owner_id #{doorkeeper_token.resource_owner_id} does not exist"
          render_json({ error: "unauthorized", message: "Access token is invalid - user not found" }, status: :unauthorized)
          return false
        end
      else
        Rails.logger.warn "API OAuth Token Invalid: Access token missing resource_owner_id"
        render_json({ error: "unauthorized", message: "Access token is invalid - missing resource owner" }, status: :unauthorized)
        return false
      end

      @authentication_method = :oauth
      setup_current_context_for_api
      true
    rescue Doorkeeper::Errors::DoorkeeperError => e
      Rails.logger.warn "API OAuth Error: #{e.message}"
      false
    end

    # Try API key authentication
    def authenticate_api_key
      api_key_value = request.headers["X-Api-Key"]
      return false unless api_key_value

      @api_key = ApiKey.find_by_value(api_key_value)
      return false unless @api_key && @api_key.active?

      @current_user = @api_key.user
      @api_key.update_last_used!
      @authentication_method = :api_key
      @rate_limiter = ApiRateLimiter.limit(@api_key)
      setup_current_context_for_api
      true
    end

    # Check rate limits for API key authentication
    def check_api_key_rate_limit
      return unless @authentication_method == :api_key && @rate_limiter

      if @rate_limiter.rate_limit_exceeded?
        usage_info = @rate_limiter.usage_info
        render_rate_limit_exceeded(usage_info)
        return false
      end

      # Increment request count for successful API key requests
      @rate_limiter.increment_request_count!

      # Add rate limit headers to response
      add_rate_limit_headers(@rate_limiter.usage_info)
    end

    # Render rate limit exceeded response
    def render_rate_limit_exceeded(usage_info)
      response.headers["X-RateLimit-Limit"] = usage_info[:rate_limit].to_s
      response.headers["X-RateLimit-Remaining"] = "0"
      response.headers["X-RateLimit-Reset"] = usage_info[:reset_time].to_s
      response.headers["Retry-After"] = usage_info[:reset_time].to_s

      Rails.logger.warn "API Rate Limit Exceeded: API Key #{@api_key.name} (User: #{@current_user.email}) - #{usage_info[:current_count]}/#{usage_info[:rate_limit]} requests"

      render_json({
        error: "rate_limit_exceeded",
        message: "Rate limit exceeded. Try again in #{usage_info[:reset_time]} seconds.",
        details: {
          limit: usage_info[:rate_limit],
          current: usage_info[:current_count],
          reset_in_seconds: usage_info[:reset_time]
        }
      }, status: :too_many_requests)
    end

    # Add rate limit headers to successful responses
    def add_rate_limit_headers(usage_info)
      response.headers["X-RateLimit-Limit"] = usage_info[:rate_limit].to_s
      response.headers["X-RateLimit-Remaining"] = usage_info[:remaining].to_s
      response.headers["X-RateLimit-Reset"] = usage_info[:reset_time].to_s
    end

    # Render unauthorized response
    def render_unauthorized
      render_json({ error: "unauthorized", message: "Access token or API key is invalid, expired, or missing" }, status: :unauthorized)
    end

    # Returns the user that owns the access token or API key
    def current_resource_owner
      @current_user
    end

    # Get current scopes from either authentication method
    def current_scopes
      case @authentication_method
      when :oauth
        doorkeeper_token&.scopes&.to_a || []
      when :api_key
        @api_key&.scopes || []
      else
        []
      end
    end

    # Check if the current authentication has the required scope
    # Implements hierarchical scope checking where read_write includes read access
    def authorize_scope!(required_scope)
      scopes = current_scopes

      case required_scope.to_s
      when "read"
        # Read access requires either "read" or "read_write" scope
        has_access = scopes.include?("read") || scopes.include?("read_write")
      when "write"
        # Write access requires "read_write" scope
        has_access = scopes.include?("read_write")
      else
        # For any other scope, check exact match (backward compatibility)
        has_access = scopes.include?(required_scope.to_s)
      end

      unless has_access
        Rails.logger.warn "API Insufficient Scope: User #{current_resource_owner&.email} attempted to access #{required_scope} but only has #{scopes}"
        render_json({ error: "insufficient_scope", message: "This action requires the '#{required_scope}' scope" }, status: :forbidden)
        return false
      end
      true
    end

    # Consistent JSON response method
    def render_json(data, status: :ok)
      render json: data, status: status
    end

    # Error handlers
    def handle_not_found(exception)
      Rails.logger.warn "API Record Not Found: #{exception.message}"
      render_json({ error: "record_not_found", message: "The requested resource was not found" }, status: :not_found)
    end

    def handle_unauthorized(exception)
      Rails.logger.warn "API Unauthorized: #{exception.message}"
      render_json({ error: "unauthorized", message: "Access token is invalid or expired" }, status: :unauthorized)
    end

    def handle_bad_request(exception)
      Rails.logger.warn "API Bad Request: #{exception.message}"
      render_json({ error: "bad_request", message: "Required parameters are missing or invalid" }, status: :bad_request)
    end

    # Log API access for monitoring and debugging
    def log_api_access
      return unless current_resource_owner

      auth_info = case @authentication_method
      when :oauth
        "OAuth Token"
      when :api_key
        "API Key: #{@api_key.name}"
      else
        "Unknown"
      end

      Rails.logger.info "API Request: #{request.method} #{request.path} - User: #{current_resource_owner.email} (Family: #{current_resource_owner.family_id}) - Auth: #{auth_info}"
    end

    # Family-based access control helper (to be used by subcontrollers)
    def ensure_current_family_access(resource)
      return unless resource.respond_to?(:family_id)

      unless resource.family_id == current_resource_owner.family_id
        Rails.logger.warn "API Forbidden: User #{current_resource_owner.email} attempted to access resource from family #{resource.family_id}"
        render_json({ error: "forbidden", message: "Access denied to this resource" }, status: :forbidden)
        return false
      end

      true
    end

    # Manual doorkeeper_token accessor for compatibility with manual token verification
    def doorkeeper_token
      @_doorkeeper_token
    end

    # Set up Current context for API requests since we don't use session-based auth
    def setup_current_context_for_api
      # For API requests, we need to create a minimal session-like object
      # or find/create an actual session for this user to make Current.user work
      if @current_user
        # Try to find an existing session for this user, or create a temporary one
        session = @current_user.sessions.first
        if session
          Current.session = session
        else
          # Create a temporary session for this API request
          # This won't be persisted but will allow Current.user to work
          session = @current_user.sessions.build(
            user_agent: request.user_agent,
            ip_address: request.ip
          )
          Current.session = session
        end
      end
    end

    # Check if AI features are enabled for the current user
    def require_ai_enabled
      unless current_resource_owner&.ai_enabled?
        render_json({ error: "feature_disabled", message: "AI features are not enabled for this user" }, status: :forbidden)
      end
    end
end
