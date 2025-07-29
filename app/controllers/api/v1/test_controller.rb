# frozen_string_literal: true

# Test controller for API V1 Base Controller functionality
# This controller is only used for testing the base controller behavior
class Api::V1::TestController < Api::V1::BaseController
  resource_description do
    short "Endpoints for testing API base controller features (only available in test environment)"
    formats [ "json" ]
    api_version "v1"
  end

  api :GET, "/test", "Basic test endpoint"
  returns code: 200, desc: "Success message and current user email" do
    property :message, String, desc: "Success message"
    property :user, String, desc: "Email of the current resource owner"
  end
  def index
    render_json({ message: "test_success", user: current_resource_owner&.email })
  end

  api :GET, "/test_not_found", "Test endpoint for 404 Not Found error"
  returns code: 404, desc: "Not Found error"
  def not_found
    # Trigger RecordNotFound error for testing error handling
    raise ActiveRecord::RecordNotFound, "Test record not found"
  end

  api :GET, "/test_family_access", "Test family-based access control"
  returns code: 200, desc: "Family access granted" do
    property :family_id, Integer, desc: "ID of the current resource owner's family"
  end
  returns code: 403, desc: "Forbidden - family access denied"
  def family_access
    # Test family-based access control
    # Create a mock resource that belongs to a different family
    mock_resource = OpenStruct.new(family_id: 999)  # Different family ID

    # Check family access - if it returns false, it already rendered the error
    if ensure_current_family_access(mock_resource)
      # If we get here, access was allowed
      render_json({ family_id: current_resource_owner.family_id })
    end
  end

  api :GET, "/test_scope_required", "Test scope authorization (requires 'write' scope)"
  returns code: 200, desc: "Scope authorized" do
    property :message, String, desc: "Confirmation message"
    property :scopes, String, desc: "Scopes available to the current token"
    property :required_scope, String, desc: "Scope required for this endpoint"
  end
  returns code: 403, desc: "Forbidden - insufficient scope"
  def scope_required
    # Test scope authorization - require write scope
    return unless authorize_scope!("write")

    render_json({
      message: "scope_authorized",
      scopes: current_scopes,
      required_scope: "write"
    })
  end

  api :GET, "/test_multiple_scopes_required", "Test multiple scope authorization (requires 'read' scope)"
  returns code: 200, desc: "Scope authorized" do
    property :message, String, desc: "Confirmation message"
    property :scopes, String, desc: "Scopes available to the current token"
  end
  returns code: 403, desc: "Forbidden - insufficient scope"
  def multiple_scopes_required
    # Test read scope requirement
    return unless authorize_scope!("read")

    render_json({
      message: "read_scope_authorized",
      scopes: current_scopes
    })
  end
end
