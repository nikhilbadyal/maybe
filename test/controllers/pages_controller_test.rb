require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
  end

  test "dashboard" do
    get root_path
    assert_response :ok
  end

  test "dashboard respects non-custom period param (last_365_days)" do
    get root_path, params: { period: "last_365_days" }
    assert_response :ok
    assert_includes @response.body, "365D"
    refute_includes @response.body, "name=\"start_date\""
    refute_includes @response.body, "name=\"end_date\""
  end

  test "dashboard uses custom period when start and end dates are provided" do
    start_date = 10.days.ago.to_date
    end_date = Date.current
    get root_path, params: { period: "custom", start_date: start_date.to_s, end_date: end_date.to_s }
    assert_response :ok
    assert_includes @response.body, "Custom"
    assert_includes @response.body, "value=\"#{start_date}\""
    assert_includes @response.body, "value=\"#{end_date}\""
  end

  test "dashboard falls back to default when custom period is missing dates" do
    get root_path, params: { period: "custom" }
    assert_response :ok
    # default fallback is last_30_days -> 30D label
    assert_includes @response.body, "30D"
  end

  test "download_net_worth_data supports custom period csv" do
    start_date = 7.days.ago.to_date
    end_date = Date.current
    get download_net_worth_data_path(format: :csv, period: "custom", start_date: start_date.to_s, end_date: end_date.to_s)
    assert_response :success
    assert_equal "text/csv", @response.media_type
    assert_includes @response.headers["Content-Disposition"], "net_worth_data_#{start_date}_to_#{end_date}.csv"
  end

  test "changelog" do
    VCR.use_cassette("git_repository_provider/fetch_latest_release_notes") do
      get changelog_path
      assert_response :ok
    end
  end

  test "changelog with nil release notes" do
    # Mock the GitHub provider to return nil (simulating API failure or no releases)
    github_provider = mock
    github_provider.expects(:fetch_latest_release_notes).returns(nil)
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok
    assert_select "h2", text: "Release notes unavailable"
    assert_select "a[href='https://github.com/maybe-finance/maybe/releases']"
  end

  test "changelog with incomplete release notes" do
    # Mock the GitHub provider to return incomplete data (missing some fields)
    github_provider = mock
    incomplete_data = {
      avatar: nil,
      username: "maybe-finance",
      name: "Test Release",
      published_at: nil,
      body: nil
    }
    github_provider.expects(:fetch_latest_release_notes).returns(incomplete_data)
    Provider::Registry.stubs(:get_provider).with(:github).returns(github_provider)

    get changelog_path
    assert_response :ok
    assert_select "h2", text: "Test Release"
    # Should not crash even with nil values
  end
end
