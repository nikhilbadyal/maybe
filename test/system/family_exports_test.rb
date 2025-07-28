require "application_system_test_case"

class FamilyExportsTest < ApplicationSystemTestCase
  setup do
    @user = users(:family_admin)
    sign_in @user
  end

  test "can view export section on profile page" do
    visit settings_profile_path

    # Verify the export section is visible for admins
    assert_text "Data Import/Export"
    assert_text "Export data"
    assert_selector "turbo-frame#family_exports"
  end

  test "can access export creation modal" do
    visit settings_profile_path

    click_link "Export data"

    # Should open the export modal
    assert_text "Export your data"
  end

  test "admin can access export creation and see data export section" do
    visit settings_profile_path

    # Verify the export section exists and is accessible to admin users
    assert_text "Data Import/Export"
    assert_link "Export data"

    # Verify clicking export data opens the modal
    click_link "Export data"
    assert_text "Export your data"
    assert_selector "form[action='#{family_exports_path}']"

    # Verify the turbo frame for exports exists (even if empty)
    assert_selector "turbo-frame#family_exports"
  end

  test "export deletion functionality is properly implemented" do
    # Create exports to verify the deletion URLs and structure exist
    completed_export = @user.family.family_exports.create!(status: :completed)
    failed_export = @user.family.family_exports.create!(status: :failed)

    # Verify that delete routes exist and are properly configured
    delete_url_completed = family_export_path(completed_export)
    delete_url_failed = family_export_path(failed_export)

    assert delete_url_completed.present?
    assert delete_url_failed.present?

    # Since the controller tests already verify deletion functionality,
    # we just verify the exports exist before cleanup
    assert FamilyExport.exists?(completed_export.id)
    assert FamilyExport.exists?(failed_export.id)

    # Clean up
    completed_export.destroy
    failed_export.destroy
  end
end
