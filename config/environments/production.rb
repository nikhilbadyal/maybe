require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "local").to_sym

  # Set Active Storage URL expiration time to 7 days
  config.active_storage.urls_expire_in = 7.days


  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = ActiveModel::Type::Boolean.new.cast(ENV.fetch("RAILS_ASSUME_SSL", true))

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ActiveModel::Type::Boolean.new.cast(ENV.fetch("RAILS_FORCE_SSL", true))

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  base_logger =
  if ENV["LOGTAIL_API_KEY"].present? && ENV["LOGTAIL_INGESTING_HOST"].present?
    Logtail::Logger.create_default_logger(
      ENV["LOGTAIL_API_KEY"],
      ingesting_host: ENV["LOGTAIL_INGESTING_HOST"]
    )
  else
    ActiveSupport::Logger.new(STDOUT).tap do |logger|
      logger.formatter = ::Logger::Formatter.new
    end
  end

  config.logger = ActiveSupport::TaggedLogging.new(base_logger)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  # config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  if ENV["CACHE_REDIS_URL"].present?
    config.cache_store = :redis_cache_store, { url: ENV["CACHE_REDIS_URL"] }
  end

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Don’t cache mailer views
  config.action_mailer.perform_caching = false

  # Queue name for ActiveJob deliver_later
  config.action_mailer.deliver_later_queue_name = :high_priority

  # Set host for URL helpers in mailers
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_DOMAIN", "example.com")
  }

  # SMTP delivery method
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address:              ENV["SMTP_ADDRESS"],
    port:                 ENV["SMTP_PORT"],
    user_name:            ENV["SMTP_USERNAME"],
    password:             ENV["SMTP_PASSWORD"],
    authentication:       ENV.fetch("SMTP_AUTH_METHOD", "plain").to_sym,
    enable_starttls_auto: ENV["SMTP_TLS_ENABLED"] == "true"
  }

  # Optional: raise delivery errors in production if you want failures visible
  config.action_mailer.raise_delivery_errors =
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("RAISE_MAIL_ERRORS", false))

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # set REDIS_URL for Sidekiq to use Redis
  config.active_job.queue_adapter = :sidekiq
end
