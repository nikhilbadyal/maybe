require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  setup do
    login_as users(:family_admin)
  end

  test "changing preset period auto-applies, custom reveals date inputs and does not auto-apply" do
    visit root_path

    # Open the period menu (stable selector)
    find("#net-worth-period-menu-btn").click

    # Choose a preset period (365D) and ensure it auto-applies (menu closes and label updates)
    find("select[name='period']").select("365D")
    assert_selector(:button, text: "365D")

    # URL should only contain the period; no custom dates
    uri = URI.parse(page.current_url)
    params = Rack::Utils.parse_query(uri.query)
    assert_equal "last_365_days", params["period"]
    refute params.key?("start_date")
    refute params.key?("end_date")

    # Open again and pick Custom; verify inputs appear and the label on the header becomes Custom only after submit
    find("#net-worth-period-menu-btn").click
    find("select[name='period']").select("Custom")
    # The inputs are conditionally rendered only for custom; they may be injected/enabled by Stimulus
    assert_selector("input[name='start_date']", wait: 5)
    assert_selector("input[name='end_date']", wait: 5)
    old_url = page.current_url

    # Fill both dates and Apply
    start_date = (Date.current - 7).strftime("%Y-%m-%d")
    end_date = Date.current.strftime("%Y-%m-%d")

    # Change a single date should NOT auto-apply (set via JS to avoid browser date widget quirks)
    start_input = find("input[data-period-selector-target='startDate']", visible: :all)
    page.execute_script("arguments[0].value = arguments[1];", start_input, start_date)
    assert_equal old_url, page.current_url

    # Fill the other and click Apply
    end_input = find("input[data-period-selector-target='endDate']", visible: :all)
    page.execute_script("arguments[0].value = arguments[1];", end_input, end_date)
    click_on "Apply"

    # After apply, header should show Custom
    assert_selector(:button, text: "Custom")

    # URL should include custom with both dates
    uri = URI.parse(page.current_url)
    params = Rack::Utils.parse_query(uri.query)
    assert_equal "custom", params["period"]
    assert_equal start_date, params["start_date"]
    assert_equal end_date, params["end_date"]
  end

  # NEW TEST: invalid custom range feedback
  test "invalid custom range shows alert and does not apply" do
    visit root_path

    find("#net-worth-period-menu-btn").click
    find("select[name='period']").select("Custom")

    start_input = find("input[data-period-selector-target='startDate']", visible: :all)
    end_input = find("input[data-period-selector-target='endDate']", visible: :all)

    # Invalid: start after end
    start_date = Date.current.strftime("%Y-%m-%d")
    end_date = (Date.current - 7).strftime("%Y-%m-%d")

    old_url = page.current_url

    page.execute_script("arguments[0].value = arguments[1];", start_input, start_date)
    page.execute_script("arguments[0].value = arguments[1];", end_input, end_date)
    click_on "Apply"

    # Should not navigate
    assert_equal old_url, page.current_url

    # Expect client-side error styling because submission is prevented
    assert end_input[:class].to_s.include?("border-destructive"), "End date input should have error styling"
    assert_no_text "The custom date range you provided is invalid"
  end
end
