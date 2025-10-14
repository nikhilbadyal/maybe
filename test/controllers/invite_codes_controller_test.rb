require "test_helper"

class InviteCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.application.config.app_mode.stubs(:self_hosted?).returns(true)
  end
  test "admin can generate invite codes" do
    sign_in users(:family_admin)

    assert_difference("InviteCode.count") do
      post invite_codes_url, params: {}
    end
  end

  test "non-admin cannot generate invite codes" do
    sign_in users(:family_member)

    assert_raises(StandardError) { post invite_codes_url, params: {} }
  end

  test "admin can delete invite codes" do
    sign_in users(:family_admin)
    invite_code = InviteCode.create!

    assert_difference("InviteCode.count", -1) do
      delete invite_code_url(invite_code)
    end

    assert_redirected_to invite_codes_url
  end

  test "non-admin cannot delete invite codes" do
    sign_in users(:family_member)
    invite_code = InviteCode.create!

    assert_raises(StandardError) do
      delete invite_code_url(invite_code)
    end

    assert InviteCode.exists?(invite_code.id), "Invite code should not be deleted"
  end

  test "handles destroy failures gracefully" do
    sign_in users(:family_admin)
    invite_code = InviteCode.create!

    # Mock destroy to return false
    InviteCode.any_instance.stubs(:destroy).returns(false)

    delete invite_code_url(invite_code)

    assert_redirected_to invite_codes_url
    assert_equal "Failed to delete invite code", flash[:alert]
    assert InviteCode.exists?(invite_code.id), "Invite code should still exist"
  end

  test "handles non-existent invite codes" do
    sign_in users(:family_admin)

    delete invite_code_url("non-existent-id")

    assert_redirected_to invite_codes_url
    assert_equal "Invite code not found", flash[:alert]
  end
end
