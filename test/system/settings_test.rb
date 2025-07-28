require "application_system_test_case"

class SettingsTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)

    @settings_links = [
      [ "Account", settings_profile_path ],
      [ "Preferences", settings_preferences_path ],
      [ "Accounts", accounts_path ],
      [ "Tags", tags_path ],
      [ "Categories", categories_path ],
      [ "Merchants", family_merchants_path ],
      [ "Imports", imports_path ],
      [ "What's new", changelog_path ],
      [ "Feedback", feedback_path ]
    ]
  end

  test "can access settings from sidebar" do
    VCR.use_cassette("git_repository_provider/fetch_latest_release_notes") do
      open_settings_from_sidebar
      assert_selector "h1", text: "Account"
      assert_current_path settings_profile_path, ignore_query: true

      @settings_links.each do |name, path|
        click_link name
        assert_selector "h1", text: name
        assert_current_path path
      end
    end
  end

  test "can update self hosting settings" do
    Rails.application.config.app_mode.stubs(:self_hosted?).returns(true)
    Provider::Registry.stubs(:get_provider).with(:synth).returns(nil)
    open_settings_from_sidebar
    assert_selector "li", text: "Self hosting"
    click_link "Self hosting"
    assert_current_path settings_hosting_path
    assert_selector "h1", text: "Self-Hosting"
    check "setting[require_invite_for_signup]", allow_label_click: true
    click_button "Generate new code"
    assert_selector 'span[data-clipboard-target="source"]', visible: true, count: 1 # invite code copy widget
    copy_button = find('button[data-action="clipboard#copy"]', match: :first) # Find the first copy button (adjust if needed)
    copy_button.click
    assert_selector 'span[data-clipboard-target="iconSuccess"]', visible: true, count: 1 # text copied and icon changed to checkmark
  end

  test "displays data provider preference toggle" do
    open_settings_from_sidebar
    click_link "Preferences"
    assert_current_path settings_preferences_path
    assert_selector "h1", text: "Preferences"

    # Should show the data provider section
    assert_text "Data Provider"
    assert_text "Use Data Provider"
    assert_text "Control whether Maybe fetches historical data"

    # Should have the toggle form elements
    assert_selector "input[name='user[family_attributes][use_data_provider]'][type='checkbox']", visible: false
    assert_selector "label[for='family_use_data_provider']"

    # Toggle should be checked by default (since fixture has use_data_provider: true)
    toggle = find("input[name='user[family_attributes][use_data_provider]'][type='checkbox']", visible: false)
    assert toggle.checked?, "Toggle should be checked by default"
  end

  # Note: Skipping the full system test for warning behavior due to unrelated accounts page errors
  # The functionality is tested at the model and controller level

  test "does not show billing link if self hosting" do
    Rails.application.config.app_mode.stubs(:self_hosted?).returns(true)
    open_settings_from_sidebar
    assert_no_selector "li", text: I18n.t("settings.settings_nav.billing_label")
  end

  private

    def open_settings_from_sidebar
      within "div[data-testid=user-menu]" do
        find("button").click
      end
      click_link "Settings"
    end
end
