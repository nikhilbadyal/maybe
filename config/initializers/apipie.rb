Apipie.configure do |config|
  config.app_name                = "Maybe API"
  config.api_base_url            = "/api"
  config.doc_base_url            = "/docs"
  config.default_version         = "v1"

  # ============================================================================
  # API CONTROLLERS AND ROUTES
  # ============================================================================

  # where is your API defined?
  config.api_controllers_matcher = "#{Rails.root}/app/controllers/api/**/*.rb"

  # Use controller paths instead of names to prevent conflicts
  config.namespaced_resources = true

  # ============================================================================
  # VALIDATION AND PROCESSING
  # ============================================================================

  # Disable parameter validation to avoid test conflicts while keeping documentation
  config.validate = false
  config.validate_value = false
  config.validate_presence = false
  config.validate_key = false
  config.process_params = false

  # ============================================================================
  # DOCUMENTATION FEATURES
  # ============================================================================

  # Enable reloading in development
  config.reload_controllers = Rails.env.development?

  # Show all examples in documentation
  config.show_all_examples = true

  # Compress examples for better performance
  config.compress_examples = true

  # Use .html extension for API pages
  config.link_extension = ".html"

  # ============================================================================
  # MARKUP AND FORMATTING
  # ============================================================================

  # Use Markdown for rich descriptions (requires kramdown gem)
  begin
    require "kramdown"
    config.markup = Apipie::Markup::Markdown.new
  rescue LoadError
    # Fallback to RDoc if Markdown not available
    config.markup = Apipie::Markup::RDoc.new
  end

  # ============================================================================
  # AUTHENTICATION AND AUTHORIZATION
  # ============================================================================

  # Configure authentication for API documentation access
  config.authenticate do |controller|
    # Allow public access in development, require admin in production
    if Rails.env.development?
      true
    else
      # This assumes you are using Doorkeeper for API authentication
      # and want to restrict access to API docs to authenticated admin users.
      Current.user&.admin?
    end
  end

  # Optional authorization for specific controllers/methods
  # config.authorize = Proc.new do |controller, method, doc|
  #   # Return true to show, false to hide
  #   # Example: hide internal methods
  #   !method || !method.to_s.include?('internal')
  # end

  # ============================================================================
  # SWAGGER/OPENAPI CONFIGURATION
  # ============================================================================

  # Configure Swagger generation
  config.generator.swagger.content_type_input = :json
  config.generator.swagger.json_input_uses_refs = true
  config.generator.swagger.include_warning_tags = true
  config.generator.swagger.suppress_warnings = [ 100, 105 ]  # Suppress minor warnings
  config.generator.swagger.api_host = Rails.env.production? ? "api.maybe.co" : "localhost:3000"
  config.generator.swagger.schemes = Rails.env.production? ? [ "https" ] : [ "http", "https" ]
  config.generator.swagger.skip_default_tags = false

  # Configure API security for Swagger
  config.generator.swagger.security_definitions = {
    BearerAuth: {
      type: "apiKey",
      name: "Authorization",
      in: "header",
      description: "OAuth2 Bearer token. Format: `Bearer <token>`"
    },
    ApiKeyAuth: {
      type: "apiKey",
      name: "X-Api-Key",
      in: "header",
      description: "API Key for authentication"
    }
  }

  config.generator.swagger.global_security = [
    { BearerAuth: [] },
    { ApiKeyAuth: [] }
  ]

  # ============================================================================
  # CACHING AND PERFORMANCE
  # ============================================================================

  # Use cache in production for better performance
  config.use_cache = Rails.env.production?
  config.cache_dir = File.join(Rails.root, "public", "apipie-cache")

  # Enable JSON checksums for smart caching
  config.update_checksum = true
  config.checksum_path = [ "/api", "/docs" ]

  # ============================================================================
  # APPLICATION INFORMATION
  # ============================================================================

  config.copyright = "&copy; #{Date.current.year} Maybe Finance, Inc."

  config.app_info["1.0"] = "
  # Maybe API Documentation

    Welcome to the **Maybe API**! This API allows external applications to securely interact with the Maybe personal finance platform.

    ## Getting Started

    1. **Authentication**: All API endpoints require authentication via OAuth2 or API Keys
    2. **Base URL**: `/api/v1`
    3. **Format**: All requests and responses use JSON
    4. **Rate Limiting**: API Key requests are rate limited based on your plan

    ## Authentication Methods

    ### OAuth2 (Recommended)
    ```http
    Authorization: Bearer your_access_token_here
    ```

    ### API Key
    ```http
    X-Api-Key: your_api_key_here
    ```

    ## Scopes

    - `read`: Read-only access to user data
    - `read_write`: Full access to user data (includes read access)

    ## SDKs and Libraries

    - [JavaScript/TypeScript SDK](https://github.com/maybe-finance/maybe-js)
    - [Python SDK](https://github.com/maybe-finance/maybe-python)
    - [Ruby Gem](https://github.com/maybe-finance/maybe-ruby)

    ## Support

    - [API Documentation](/docs)
    - [GitHub Issues](https://github.com/maybe-finance/maybe/issues)
    - [Community Discord](https://discord.gg/maybe)

    ---

    **Note**: This API is currently in **beta**. Breaking changes may occur with advance notice.
  "

  # ============================================================================
  # IGNORED CONTROLLERS
  # ============================================================================

  # Ignore non-API controllers and internal endpoints
  config.ignored = %w[
    ApplicationController
    SessionsController
    RegistrationsController
    Api::V1::TestController
  ]

  # ============================================================================
  # LOCALIZATION (if needed in the future)
  # ============================================================================

  config.default_locale = "en"
  config.languages = [ "en" ]

  # Example localization setup (uncomment if using I18n)
  # config.locale = lambda { |loc| loc ? I18n.locale = loc : I18n.locale }
  # config.translate = lambda do |str, loc|
  #   return '' if str.blank?
  #   I18n.t(str, locale: loc, scope: 'api_docs', default: str)
  # end
end
