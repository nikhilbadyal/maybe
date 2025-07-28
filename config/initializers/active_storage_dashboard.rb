# config/initializers/active_storage_dashboard.rb

require "active_storage_dashboard/engine"

if Rails.env.production?
  ActiveStorageDashboard::Engine.middleware.use(Rack::Auth::Basic) do |username, password|
    configured_username = ::Digest::SHA256.hexdigest(ENV.fetch("ACTIVE_STORAGE_DASHBOARD_USERNAME", "maybe"))
    configured_password = ::Digest::SHA256.hexdigest(ENV.fetch("ACTIVE_STORAGE_DASHBOARD_PASSWORD", "maybe"))

    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), configured_username) &&
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), configured_password)
  end
end
