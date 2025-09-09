# frozen_string_literal: true

require "test_helper"

class Api::V1::ValuationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @account = accounts(:depository)
    @oauth_app = Doorkeeper::Application.create!(
      name: "Test API App",
      redirect_uri: "https://example.com/callback",
      scopes: "read read_write"
    )
    @token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read_write"
    )
  end

  test "should create valuation with valid token and params" do
    valuation_date = Date.current.to_s
    assert_difference "Valuation.count", 1 do
      post api_v1_account_valuations_url(@account),
           params: { valuation: { balance: 1234.56, date: valuation_date } },
           headers: { Authorization: "Bearer #{@token.token}" }
    end
    assert_response :created
    assert_equal "Valuation created successfully.", JSON.parse(response.body)["message"]
  end

  test "should not create valuation with invalid token" do
    post api_v1_account_valuations_url(@account),
         params: { valuation: { balance: 1234.56, date: Date.current.to_s } },
         headers: { Authorization: "Bearer invalid" }
    assert_response :unauthorized
  end

  test "should not create valuation with insufficient scope" do
    read_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read"
    )
    post api_v1_account_valuations_url(@account),
         params: { valuation: { balance: 1234.56, date: Date.current.to_s } },
         headers: { Authorization: "Bearer #{read_token.token}" }
    assert_response :forbidden
  end

  test "should return not found for non-existent account" do
    post api_v1_account_valuations_url("not-an-account"),
         params: { valuation: { balance: 1234.56, date: Date.current.to_s } },
         headers: { Authorization: "Bearer #{@token.token}" }
    assert_response :not_found
  end

  test "should return bad request for missing params" do
    post api_v1_account_valuations_url(@account),
         params: { valuation: { balance: 1234.56 } }, # Missing date
         headers: { Authorization: "Bearer #{@token.token}" }
    assert_response :bad_request
  end

  test "returns 422 for invalid date format" do
    post api_v1_account_valuations_url(@account),
         params: { valuation: { balance: 1234.56, date: "15-01-2024" } },
         headers: { Authorization: "Bearer #{@token.token}" }
    assert_response :unprocessable_entity
    response_body = JSON.parse(response.body)
    assert_equal "Invalid date format. Please use YYYY-MM-DD format.", response_body["message"]
  end

  test "returns 422 for non-numeric balance" do
    post api_v1_account_valuations_url(@account),
         params: { valuation: { balance: "abc", date: Date.current.to_s } },
         headers: { Authorization: "Bearer #{@token.token}" }
    assert_response :unprocessable_entity
    response_body = JSON.parse(response.body)
    assert_equal "Invalid balance format. Please ensure balance is a valid number.", response_body["message"]
  end

  test "returns 400 for nil balance" do
    post api_v1_account_valuations_url(@account),
         params: { valuation: { balance: nil, date: Date.current.to_s } },
         headers: { Authorization: "Bearer #{@token.token}" }
    assert_response :bad_request
    response_body = JSON.parse(response.body)
    assert_equal "Required parameters are missing or invalid", response_body["message"]
  end

  test "returns 422 for inactive accounts" do
    @account.disable!

    post api_v1_account_valuations_url(@account),
         params: { valuation: { balance: 1000.00, date: Date.current.to_s } },
         headers: { Authorization: "Bearer #{@token.token}" }
    assert_response :unprocessable_entity
    response_body = JSON.parse(response.body)
    assert_equal "Cannot create valuations for inactive accounts.", response_body["message"]
    assert_equal "Account status: disabled", response_body["details"]
  end

  test "returns 422 for future dates" do
    future_date = 1.day.from_now.to_date.to_s

    post api_v1_account_valuations_url(@account),
         params: { valuation: { balance: 1000.00, date: future_date } },
         headers: { Authorization: "Bearer #{@token.token}" }
    assert_response :unprocessable_entity
    response_body = JSON.parse(response.body)
    assert_equal "Cannot create valuations for future dates.", response_body["message"]
  end

  test "returns 422 for dates before account start date" do
    start_date = @account.start_date
    before_start_date = (start_date - 1.day).to_s

    post api_v1_account_valuations_url(@account),
         params: { valuation: { balance: 1000.00, date: before_start_date } },
         headers: { Authorization: "Bearer #{@token.token}" }
    assert_response :unprocessable_entity
    response_body = JSON.parse(response.body)
    assert_equal "Cannot create valuations before account start date.", response_body["message"]
  end

  test "returns valuation data in successful response" do
    valuation_date = Date.current.to_s
    post api_v1_account_valuations_url(@account),
         params: { valuation: { balance: 1500.75, date: valuation_date } },
         headers: { Authorization: "Bearer #{@token.token}" }
    assert_response :created

    response_body = JSON.parse(response.body)
    assert_equal "Valuation created successfully.", response_body["message"]

    # Check valuation data
    assert response_body["valuation"].present?
    valuation_data = response_body["valuation"]
    assert valuation_data["id"].present?
    assert_equal valuation_date, valuation_data["date"]
    assert_equal "1500.75", valuation_data["amount"].to_s
    assert_equal @account.currency, valuation_data["currency"]
    assert valuation_data["created_at"].present?
    assert valuation_data["updated_at"].present?

    # Check balance changes data
    assert response_body["balance_changes"].present?
    balance_changes = response_body["balance_changes"]
    assert_equal "1500.75", balance_changes["new_balance"].to_s
  end
end
