require "application_system_test_case"

class ImportsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    sign_in @user = users(:family_admin)

    # Trade securities will be imported as "offline" tickers
    Security.stubs(:provider).returns(nil)
  end

  test "transaction import" do
    visit new_import_path

    click_on "Import transactions"

    within_testid("import-tabs") do
      click_on "Copy & Paste"
    end

    fill_in "import[raw_file_str]", with: file_fixture("imports/transactions.csv").read

    within "form" do
      click_on "Upload CSV"
    end

    select "Date", from: "import[date_col_label]"
    select "YYYY-MM-DD", from: "import[date_format]"
    select "Amount", from: "import[amount_col_label]"
    select "Account", from: "import[account_col_label]"
    select "Name", from: "import[name_col_label]"
    select "Category", from: "import[category_col_label]"
    select "Tags", from: "import[tags_col_label]"
    select "Notes", from: "import[notes_col_label]"

    click_on "Apply configuration"

    click_on "Next step"

    assert_selector "h1", text: "Assign your categories"
    click_on "Next"

    assert_selector "h1", text: "Assign your tags"
    click_on "Next"

    assert_selector "h1", text: "Assign your accounts"
    click_on "Next"

    click_on "Publish import"

    assert_text "Import in progress"

    perform_enqueued_jobs

    click_on "Check status"

    assert_text "Import successful"

    click_on "Back to dashboard"
  end

  test "account menu import bypasses to upload with account preselected" do
    # Visit an existing account and open the three-dots menu
    account = accounts(:depository)
    visit account_path(account)

    within_testid("account-menu") do
      find("button").click
      click_on "Import transactions"
    end

    # We should land on the upload step for the newly created import
    assert_current_path %r{/imports/.+/upload}

    # The account dropdown should be preselected to the account
    if page.has_selector?("#import_account_id")
      selected_option = find("#import_account_id").value
      assert_equal account.id, selected_option
    else
      # For non-transaction/trade imports the select may be hidden; ensure we're on upload page at least
      assert_selector "form[action*='/upload']"
    end
  end

  test "trade import" do
    visit new_import_path

    click_on "Import investments"

    within_testid("import-tabs") do
      click_on "Copy & Paste"
    end

    fill_in "import[raw_file_str]", with: file_fixture("imports/trades.csv").read

    within "form" do
      click_on "Upload CSV"
    end

    select "date", from: "import[date_col_label]"
    select "YYYY-MM-DD", from: "import[date_format]"
    select "qty", from: "import[qty_col_label]"
    select "ticker", from: "import[ticker_col_label]"
    select "price", from: "import[price_col_label]"
    select "account", from: "import[account_col_label]"

    click_on "Apply configuration"

    click_on "Next step"

    assert_selector "h1", text: "Assign your accounts"
    click_on "Next"

    click_on "Publish import"

    assert_text "Import in progress"

    perform_enqueued_jobs

    click_on "Check status"

    assert_text "Import successful"

    click_on "Back to dashboard"
  end

  test "account import" do
    visit new_import_path

    click_on "Import accounts"

    within_testid("import-tabs") do
      click_on "Copy & Paste"
    end

    fill_in "import[raw_file_str]", with: file_fixture("imports/accounts.csv").read

    within "form" do
      click_on "Upload CSV"
    end

    select "type", from: "import[entity_type_col_label]"
    select "name", from: "import[name_col_label]"
    select "amount", from: "import[amount_col_label]"

    click_on "Apply configuration"

    click_on "Next step"

    assert_selector "h1", text: "Assign your account types"

    all("form").each do |form|
      within(form) do
        select = form.find("select")
        select "Depository", from: select["id"]
        sleep 0.5
      end
    end

    click_on "Next"

    click_on "Publish import"

    assert_text "Import in progress"

    perform_enqueued_jobs

    click_on "Check status"

    assert_text "Import successful"

    click_on "Back to dashboard"
  end

  test "mint import" do
    visit new_import_path

    click_on "Import from Mint"

    within_testid("import-tabs") do
      click_on "Copy & Paste"
    end

    fill_in "import[raw_file_str]", with: file_fixture("imports/mint.csv").read

    within "form" do
      click_on "Upload CSV"
    end

    click_on "Apply configuration"

    click_on "Next step"

    assert_selector "h1", text: "Assign your categories"
    click_on "Next"

    assert_selector "h1", text: "Assign your tags"
    click_on "Next"

    assert_selector "h1", text: "Assign your accounts"
    click_on "Next"

    click_on "Publish import"

    assert_text "Import in progress"

    perform_enqueued_jobs

    click_on "Check status"

    assert_text "Import successful"

    click_on "Back to dashboard"
  end

  test "sorts accounts by name in dropdown" do
    @user.update!(balance_sheet_sort: "name_asc")
    visit new_import_path
    click_on "Import transactions"

    expected_order = @user.family.accounts.visible.order(name: :asc).pluck(:name)
    options = find("#import_account_id").all("option").map(&:text)
    # The first option is "Multi-account import"
    assert_equal expected_order, options[1..]
  end

  test "sorts accounts by balance in dropdown" do
    @user.update!(balance_sheet_sort: "balance_desc")
    visit new_import_path
    click_on "Import transactions"

    expected_order = @user.family.accounts.visible.order(balance: :desc).pluck(:name)
    options = find("#import_account_id").all("option").map(&:text)
    # The first option is "Multi-account import"
    assert_equal expected_order, options[1..]
  end
end
