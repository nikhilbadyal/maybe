require "test_helper"

class Settings::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "get" do
    get settings_preferences_url
    assert_response :success
  end

  test "preferences page includes data provider toggle" do
    get settings_preferences_url
    assert_response :success

    # Should show the data provider section
    assert_select "h2", text: "Data Provider"
    assert_select "label", text: "Use Data Provider"

    # Should include the toggle input
    assert_select "input[name='user[family_attributes][use_data_provider]'][type='checkbox']"
  end
end
