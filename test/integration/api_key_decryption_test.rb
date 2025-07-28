# frozen_string_literal: true

require "test_helper"

class ApiKeyDecryptionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.api_keys.destroy_all # Ensure clean state
    sign_in @user
  end

  test "corrupted API key in API authentication gracefully fails" do
    # Test that API authentication handles cases where API key lookup fails
    # When find_by_value returns nil (which would happen if decryption fails)
    ApiKey.stubs(:find_by_value).with("nonexistent_key").returns(nil)

    # Try to use a nonexistent API key for authentication
    get "/api/v1/accounts", headers: { "X-Api-Key" => "nonexistent_key" }

    # Should fail authentication gracefully, not crash
    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal "unauthorized", response_body["error"]
  end

  test "corrupted API keys are handled in settings pages without breaking navigation" do
    @api_key = ApiKey.create!(
      user: @user,
      name: "Corrupted API Key",
      display_key: "corrupted_key_123",
      scopes: [ "read" ]
    )

    # Simulate decryption error
    ApiKey.any_instance.stubs(:plain_key).raises(ActiveRecord::Encryption::Errors::Decryption)

    # Access settings page
    get settings_api_key_path

    # Should redirect to create new key, not crash
    assert_redirected_to new_settings_api_key_path(regenerate: true)
    follow_redirect!

    assert_response :success
    assert_select "h1", text: "Create New API Key"
  end

  test "user can recover from corrupted API key by creating new one" do
    # Test the full recovery workflow without stubbing - create and revoke a real key
    # to simulate what happens after a corrupted key is auto-revoked

    # Create and immediately revoke an API key to simulate post-corruption state
    @api_key = ApiKey.create!(
      user: @user,
      name: "Previously Corrupted API Key",
      display_key: "revoked_key_123",
      scopes: [ "read" ],
      revoked_at: 1.minute.ago
    )

    # User should see no API key page
    get settings_api_key_path
    assert_response :success
    # Check for the create API key content (might be in h2, h3, or another element)
    assert_match /Create Your API Key/, response.body

    # Create a new API key to recover
    post settings_api_key_path, params: {
      api_key: {
        name: "Recovery API Key",
        scopes: "read_write"
      }
    }

    assert_redirected_to settings_api_key_path
    follow_redirect!
    assert_response :success

    # Verify new key was created
    new_key = @user.api_keys.active.first
    assert_equal "Recovery API Key", new_key.name
    assert_includes new_key.scopes, "read_write"

    # Old key should still be revoked
    @api_key.reload
    assert @api_key.revoked?
  end

  test "corrupted API key does not break user session or authentication" do
    @api_key = ApiKey.create!(
      user: @user,
      name: "Corrupted API Key",
      display_key: "corrupted_key_123",
      scopes: [ "read" ]
    )

    # Simulate decryption error
    ApiKey.any_instance.stubs(:plain_key).raises(ActiveRecord::Encryption::Errors::Decryption)

    # User should still be able to access other settings pages
    get settings_profile_path
    assert_response :success

    get settings_preferences_path
    assert_response :success

    # And still be able to navigate back to API keys and create a new one
    get settings_api_key_path
    assert_redirected_to new_settings_api_key_path(regenerate: true)
  end
end
