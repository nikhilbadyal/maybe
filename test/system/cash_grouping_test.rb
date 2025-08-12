require "application_system_test_case"

class CashGroupingTest < ApplicationSystemTestCase
  setup do
    sign_in users(:family_admin)
  end

  test "cash accounts are grouped by subtype" do
    visit root_url

    within_testid("account-sidebar-tabs") do
      click_on "Assets"

      # Expand the Cash (Depository) disclosure
      find("details", text: "Cash").click

      # We expect a header for the Checking subtype since fixtures include one
      assert_text "Checking"

      # And we expect to see the checking account under that header
      assert_text "Plaid Depository Account"
    end
  end
end
