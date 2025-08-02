require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
  end

  test "can supply custom redirect after update" do
    patch user_url(@user), params: { user: { redirect_to: "home" } }
    assert_redirected_to root_url
  end

  test "can update user profile" do
    patch user_url(@user), params: {
      user: {
        first_name: "John",
        last_name: "Doe",
        onboarded_at: Time.current,
        profile_image: file_fixture_upload("profile_image.png", "image/png", :binary),
        family_attributes: {
          name: "New Family Name",
          country: "US",
          date_format: "%m/%d/%Y",
          currency: "USD",
          locale: "en"
        }
      }
    }

    assert_redirected_to settings_profile_url
    assert_equal "Your profile has been updated.", flash[:notice]
  end

  test "can update data provider preference" do
    assert @user.family.use_data_provider?, "Family should have use_data_provider enabled by default"

    patch user_url(@user), params: {
      user: {
        family_attributes: {
          id: @user.family.id,
          use_data_provider: "0"
        }
      }
    }

    assert_redirected_to settings_profile_url
    assert_not @user.family.reload.use_data_provider?, "Data provider preference should be disabled"
  end

  test "can enable data provider preference" do
    @user.family.update!(use_data_provider: false)

    patch user_url(@user), params: {
      user: {
        family_attributes: {
          id: @user.family.id,
          use_data_provider: "1"
        }
      }
    }

    assert_redirected_to settings_profile_url
    assert @user.family.reload.use_data_provider?, "Data provider preference should be enabled"
  end

  test "admin can reset family data" do
    account = accounts(:investment)
    category = categories(:income)
    tag = tags(:one)
    merchant = merchants(:netflix)
    import = imports(:transaction)
    budget = budgets(:one)
    plaid_item = plaid_items(:one)

    Provider::Plaid.any_instance.expects(:remove_item).with(plaid_item.access_token).once

    perform_enqueued_jobs(only: FamilyResetJob) do
      delete reset_user_url(@user)
    end

    assert_redirected_to settings_profile_url
    assert_equal I18n.t("users.reset.success"), flash[:notice]

    assert_not Account.exists?(account.id)
    assert_not Category.exists?(category.id)
    assert_not Tag.exists?(tag.id)
    assert_not Merchant.exists?(merchant.id)
    assert_not Import.exists?(import.id)
    assert_not Budget.exists?(budget.id)
    assert_not PlaidItem.exists?(plaid_item.id)
  end

  test "non-admin cannot reset family data" do
    sign_in @member = users(:family_member)

    delete reset_user_url(@member)

    assert_redirected_to settings_profile_url
    assert_equal I18n.t("users.reset.unauthorized"), flash[:alert]
    assert_no_enqueued_jobs only: FamilyResetJob
  end

  test "member can deactivate their account" do
    sign_in @member = users(:family_member)
    delete user_url(@member)

    assert_redirected_to root_url

    assert_not User.find(@member.id).active?
    assert_enqueued_with(job: UserPurgeJob, args: [ @member ])
  end

  test "admin prevented from deactivating when other users are present" do
    sign_in @admin = users(:family_admin)
    delete user_url(users(:family_member))

    assert_redirected_to settings_profile_url
    assert_equal "Admin cannot delete account while other users are present. Please delete all members first.", flash[:alert]
    assert_no_enqueued_jobs only: UserPurgeJob
    assert User.find(@admin.id).active?
  end

  test "admin can deactivate their account when they are the last user in the family" do
    sign_in @admin = users(:family_admin)
    users(:family_member).destroy

    delete user_url(@admin)

    assert_redirected_to root_url
    assert_not User.find(@admin.id).active?
    assert_enqueued_with(job: UserPurgeJob, args: [ @admin ])
  end

  test "can update balance_sheet_sort preference" do
    assert_equal "name_asc", @user.balance_sheet_sort, "Should start with default sort"

    patch user_url(@user), params: {
      user: {
        balance_sheet_sort: "balance_desc"
      }
    }

    assert_redirected_to settings_profile_url
    assert_equal "balance_desc", @user.reload.balance_sheet_sort, "Should update sort preference"
  end

  test "rejects invalid balance_sheet_sort preference" do
    original_sort = @user.balance_sheet_sort

    patch user_url(@user), params: {
      user: {
        balance_sheet_sort: "invalid_sort"
      }
    }

    assert_response :unprocessable_entity
    assert_equal original_sort, @user.reload.balance_sheet_sort, "Should not change sort preference"
  end

  test "can update balance_sheet_sort along with other user attributes" do
    patch user_url(@user), params: {
      user: {
        first_name: "Updated",
        balance_sheet_sort: "name_desc",
        family_attributes: {
          id: @user.family.id,
          name: "Updated Family"
        }
      }
    }

    assert_redirected_to settings_profile_url

    updated_user = @user.reload
    assert_equal "Updated", updated_user.first_name
    assert_equal "name_desc", updated_user.balance_sheet_sort
    assert_equal "Updated Family", updated_user.family.name
  end

  test "balance_sheet_sort preference is included in permitted parameters" do
    # This test ensures the parameter is whitelisted and won't be filtered out
    patch user_url(@user), params: {
      user: {
        balance_sheet_sort: "balance_asc"
      }
    }

    assert_response :redirect
    assert_equal "balance_asc", @user.reload.balance_sheet_sort
  end
end
