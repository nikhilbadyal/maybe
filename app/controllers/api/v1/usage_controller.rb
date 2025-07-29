class Api::V1::UsageController < Api::V1::BaseController
  resource_description do
    short "API for retrieving API key and rate limit usage information"
    formats [ "json" ]
    api_version "v1"
  end

  api :GET, "/usage", "Retrieve API key and rate limit usage information"
  returns code: 200, desc: "API key usage and rate limit details" do
    property :api_key, Hash, desc: "API key details (if authenticated via API key)" do
      property :name, String, desc: "Name of the API key"
      property :scopes, String, desc: "Scopes granted to the API key"
      property :last_used_at, DateTime, desc: "Timestamp of last use"
      property :created_at, DateTime, desc: "Timestamp of creation"
    end
    property :rate_limit, Hash, desc: "Current rate limit status (if authenticated via API key)" do
      property :tier, String, desc: "Rate limit tier"
      property :limit, Integer, desc: "Total requests allowed per reset period"
      property :current_count, Integer, desc: "Requests made in current period"
      property :remaining, Integer, desc: "Remaining requests in current period"
      property :reset_in_seconds, Integer, desc: "Time until reset in seconds"
      property :reset_at, DateTime, desc: "Timestamp when rate limit resets"
    end
    property :authentication_method, String, desc: "Authentication method used (oauth)"
    property :message, String, desc: "Informational message for OAuth authentication"
  end
  returns code: 401, desc: "Unauthorized - missing or invalid authentication"
  returns code: 403, desc: "Forbidden - insufficient scope"
  returns code: 400, desc: "Bad request - invalid authentication method"
  def show
    return unless authorize_scope!(:read)

    case @authentication_method
    when :api_key
      usage_info = @rate_limiter.usage_info
      render_json({
        api_key: {
          name: @api_key.name,
          scopes: @api_key.scopes,
          last_used_at: @api_key.last_used_at,
          created_at: @api_key.created_at
        },
        rate_limit: {
          tier: usage_info[:tier],
          limit: usage_info[:rate_limit],
          current_count: usage_info[:current_count],
          remaining: usage_info[:remaining],
          reset_in_seconds: usage_info[:reset_time],
          reset_at: Time.current + usage_info[:reset_time].seconds
        }
      })
    when :oauth
      # For OAuth, we don't track detailed usage yet, but we can return basic info
      render_json({
        authentication_method: "oauth",
        message: "Detailed usage tracking is available for API key authentication"
      })
    else
      render_json({
        error: "invalid_authentication_method",
        message: "Unable to determine usage information"
      }, status: :bad_request)
    end
  end
end
