require "test_helper"

class FamilyTest < ActiveSupport::TestCase
  include SyncableInterfaceTest

  def setup
    @syncable = families(:dylan_family)
    @family = families(:dylan_family)
  end

  test "missing_data_provider? returns false when use_data_provider is disabled" do
    @family.update!(use_data_provider: false)

    # Even if provider is missing and family requires one, should return false
    @family.stubs(:requires_data_provider?).returns(true)
    Provider::Registry.stubs(:get_provider).with(:synth).returns(nil)

    assert_not @family.missing_data_provider?
  end

  test "missing_data_provider? returns false when use_data_provider is enabled but family doesn't require provider" do
    @family.update!(use_data_provider: true)

    @family.stubs(:requires_data_provider?).returns(false)
    Provider::Registry.stubs(:get_provider).with(:synth).returns(nil)

    assert_not @family.missing_data_provider?
  end

  test "missing_data_provider? returns false when use_data_provider is enabled and provider is available" do
    @family.update!(use_data_provider: true)

    @family.stubs(:requires_data_provider?).returns(true)
    Provider::Registry.stubs(:get_provider).with(:synth).returns(OpenStruct.new)

    assert_not @family.missing_data_provider?
  end

  test "missing_data_provider? returns true when use_data_provider is enabled, family requires provider, and provider is missing" do
    @family.update!(use_data_provider: true)

    @family.stubs(:requires_data_provider?).returns(true)
    Provider::Registry.stubs(:get_provider).with(:synth).returns(nil)

    assert @family.missing_data_provider?
  end
end
