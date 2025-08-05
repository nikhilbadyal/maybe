require "test_helper"

class Import::UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @import = imports(:transaction)
  end

  test "show" do
    get import_upload_url(@import)
    assert_response :success
  end

  test "show sorts accounts by name" do
    @user.update!(balance_sheet_sort: "name_asc")

    get import_upload_url(@import)

    sorted_accounts = assigns(:sorted_accounts)
    expected_order = @user.family.accounts.visible.order(name: :asc).pluck(:name)
    assert_equal expected_order, sorted_accounts.pluck(:name)
  end

  test "show sorts accounts by balance" do
    @user.update!(balance_sheet_sort: "balance_desc")

    get import_upload_url(@import)

    sorted_accounts = assigns(:sorted_accounts)
    expected_order = @user.family.accounts.visible.order(balance: :desc).pluck(:name)
    assert_equal expected_order, sorted_accounts.pluck(:name)
  end

  test "uploads valid csv by copy and pasting" do
    patch import_upload_url(@import), params: {
      import: {
        raw_file_str: file_fixture("imports/valid.csv").read,
        col_sep: ","
      }
    }

    assert_redirected_to import_configuration_url(@import, template_hint: true)
    assert_equal "CSV uploaded successfully.", flash[:notice]
  end

  test "uploads valid csv by file" do
    patch import_upload_url(@import), params: {
      import: {
        csv_file: file_fixture_upload("imports/valid.csv"),
        col_sep: ","
      }
    }

    assert_redirected_to import_configuration_url(@import, template_hint: true)
    assert_equal "CSV uploaded successfully.", flash[:notice]
  end

  test "invalid csv cannot be uploaded" do
    patch import_upload_url(@import), params: {
      import: {
        csv_file: file_fixture_upload("imports/invalid.csv"),
        col_sep: ","
      }
    }

    assert_response :unprocessable_entity
    assert_equal "Must be valid CSV with headers and at least one row of data", flash[:alert]
  end
end
