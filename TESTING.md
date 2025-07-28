# Testing Guide

This guide explains how to write and run tests for the Maybe project. We use **Minitest + Fixtures** for testing to maximize familiarity and predictability.

## 🚀 Quick Start

### 1. Set Up Test Environment

```bash
# Create and set up test database
bin/rails db:create RAILS_ENV=test
bin/rails db:schema:load RAILS_ENV=test
bin/rails db:seed RAILS_ENV=test

# Set environment for current session
bin/rails db:environment:set RAILS_ENV=test
```

### 2. Run Tests

```bash
# Run all unit and integration tests
bin/rails test

# Run system tests (browser automation)
bin/rails test:system

# Run specific test file
bin/rails test test/models/family_test.rb

# Run specific test method
bin/rails test test/models/family_test.rb -n test_missing_data_provider

# Run tests with verbose output
bin/rails test --verbose
```

## 📝 Writing Tests

### Testing Philosophy

- **Practical approach**: Write tests for critical and important code paths
- **Minimal, effective tests**: Tests should significantly increase confidence in the codebase
- **Boundary testing**: Test interfaces and contracts, not implementation details
- **Use fixtures**: Prefer fixtures over factories for predictable test data

### Test Types

#### 1. Model Tests (`test/models/`)

Test business logic and domain behavior:

```ruby
require "test_helper"

class FamilyTest < ActiveSupport::TestCase
  def setup
    @family = families(:dylan_family)
  end

  test "missing_data_provider? returns false when use_data_provider is disabled" do
    @family.update!(use_data_provider: false)
    
    # Mock external dependencies
    @family.stubs(:requires_data_provider?).returns(true)
    Provider::Registry.stubs(:get_provider).with(:synth).returns(nil)
    
    assert_not @family.missing_data_provider?
  end
end
```

**Key Patterns:**
- Use `stubs` for mocking external dependencies with `mocha`
- Test all logical branches and edge cases
- Use descriptive test names that explain the scenario

#### 2. Controller Tests (`test/controllers/`)

Test request handling and parameter processing:

```ruby
require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
  end

  test "can update data provider preference" do
    assert @user.family.use_data_provider?, "Should start enabled"

    patch user_url(@user), params: {
      user: {
        family_attributes: {
          id: @user.family.id,
          use_data_provider: "0"
        }
      }
    }

    assert_redirected_to settings_profile_url
    assert_not @user.family.reload.use_data_provider?, "Should be disabled"
  end
end
```

**Key Patterns:**
- Use `sign_in` helper for authentication
- Test parameter handling and database updates
- Verify response redirects and flash messages
- Use `reload` when checking database changes

#### 3. System Tests (`test/system/`)

Test end-to-end user interactions with browser automation:

```ruby
require "application_system_test_case"

class SettingsTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)
  end

  test "displays data provider preference toggle" do
    open_settings_from_sidebar
    click_link "Preferences"
    
    assert_text "Data Provider"
    assert_text "Use Data Provider"
    
    # Check form elements are present
    assert_selector "input[name='user[family_attributes][use_data_provider]']", visible: false
    assert_selector "label[for='family_use_data_provider']"
  end

  private

  def open_settings_from_sidebar
    # Helper methods for common interactions
    click_button "Settings"
  end
end
```

**Key Patterns:**
- Use `ApplicationSystemTestCase` for browser tests
- Focus on critical user journeys
- Use helper methods for common interactions
- Test UI elements and text content
- Keep system tests minimal due to execution time

### 4. Integration Tests (`test/integration/`)

Test component interactions and API endpoints:

```ruby
require "test_helper"

class Settings::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end
  
  test "preferences page includes data provider toggle" do
    get settings_preferences_url
    assert_response :success
    
    # Verify UI elements are rendered
    assert_select "h2", text: "Data Provider"
    assert_select "input[name='user[family_attributes][use_data_provider]']"
  end
end
```

## 🧪 Testing Conventions

### Fixtures (`test/fixtures/`)

Keep fixtures minimal - 2-3 fixtures per model representing base cases:

```yaml
# test/fixtures/families.yml
empty:
  name: Family
  use_data_provider: true

dylan_family:
  name: The Dylan Family
  use_data_provider: true
```

### Mocking with Mocha

Use `mocha` gem for stubbing external dependencies:

```ruby
# Stub external API calls
Provider::Registry.stubs(:get_provider).with(:synth).returns(nil)

# Stub model methods
@family.stubs(:requires_data_provider?).returns(true)

# Verify method calls
SomeClass.expects(:some_method).with(expected_param).once
```

### Test Helpers

Use helpers in `test/support/` for common operations:

```ruby
# test/support/entries_test_helper.rb
module EntriesTestHelper
  def create_transaction(account:, **attrs)
    # Helper to create test data
  end
end
```

## 🏃‍♂️ Running Tests

### Local Development

```bash
# Run all tests
bin/rails test
bin/rails test:system

# Run specific test files
bin/rails test test/models/family_test.rb
bin/rails test test/controllers/users_controller_test.rb

# Run with pattern matching
bin/rails test test/models/ -n "missing_data_provider"

# Run system tests without parallelization (useful for debugging)
DISABLE_PARALLELIZATION=true bin/rails test:system

# Run tests with coverage (if configured)
COVERAGE=true bin/rails test
```

### Debugging Tests

```bash
# Run single test with verbose output
bin/rails test test/models/family_test.rb -n test_specific_method --verbose

# View system test screenshots on failure
open tmp/screenshots/failures_test_name.png

# Run system tests in visible browser (add to test)
driven_by :selenium, using: :chrome
```

### CI Environment

The CI runs tests with this setup:

```bash
# Database setup
bin/rails db:create
bin/rails db:schema:load
bin/rails db:seed

# Test execution
bin/rails test                           # Unit & integration tests
DISABLE_PARALLELIZATION=true bin/rails test:system  # System tests
```

**Environment Requirements:**
- PostgreSQL service running
- Redis service running  
- Chrome browser (for system tests)
- `RAILS_ENV=test`

## 🎯 Testing Best Practices

### DO ✅

- **Test critical business logic** - Focus on code that would break the application
- **Use descriptive test names** - Explain what scenario you're testing
- **Test boundaries** - Test the interface/contract, not implementation
- **Mock external dependencies** - Use stubs for APIs, external services
- **Keep fixtures minimal** - Create test data in tests when needed
- **Test error cases** - Don't just test the happy path
- **Use helpers for setup** - Reduce duplication in test setup

### DON'T ❌

- **Test ActiveRecord functionality** - Don't test framework features
- **Test implementation details** - Test what, not how
- **Create excessive fixtures** - Only create base cases in fixtures
- **Write overly complex tests** - Keep tests simple and focused
- **Test one class in another's test suite** - Keep tests isolated
- **Skip edge cases** - Test error conditions and boundary values

### Example: Good vs Bad Tests

```ruby
# ✅ GOOD - Tests critical business logic
test "syncs balances using forward calculator" do
  Balance::ForwardCalculator.any_instance.expects(:calculate).returns([
    Balance.new(date: Date.current, balance: 1000, currency: "USD")
  ])

  assert_difference "@account.balances.count", 1 do
    Balance::Syncer.new(@account).sync_balances
  end
end

# ❌ BAD - Tests ActiveRecord functionality
test "saves balance" do 
  balance = Balance.new(balance: 100, currency: "USD")
  assert balance.save
end
```

## 🔧 Troubleshooting

### Common Issues

**Database Environment Mismatch:**
```bash
bin/rails db:environment:set RAILS_ENV=test
```

**Foreign Key Violations in Fixtures:**
- Check that all fixture references point to existing records
- Ensure fixture dependencies are properly defined

**System Test Failures:**
- Check `tmp/screenshots/` for failure screenshots
- Ensure test data setup is correct
- Verify selectors match actual HTML structure

**Stale Test Data:**
```bash
# Reset test database
bin/rails db:test:prepare
```

## 📚 Additional Resources

- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)
- [Minitest Documentation](https://docs.seattlerb.org/minitest/)
- [Mocha Gem Documentation](https://mocha.jamesmead.org/)
- [Capybara DSL](https://rubydoc.info/github/teamcapybara/capybara/master/Capybara/Node/Finders)

---

## 📋 Testing Checklist

When adding a new feature:

- [ ] **Model tests** - Business logic and validations
- [ ] **Controller tests** - Parameter handling and responses  
- [ ] **Integration tests** - UI rendering and form handling
- [ ] **System tests** - Critical user journeys (sparingly)
- [ ] **Update fixtures** - Add any new required test data
- [ ] **Test edge cases** - Error conditions and boundary values
- [ ] **Verify CI passes** - All tests pass in CI environment

Following these guidelines will help ensure your tests are valuable, maintainable, and follow the project's conventions! 
