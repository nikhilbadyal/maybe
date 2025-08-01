require "application_system_test_case"

class ChatsTest < ApplicationSystemTestCase
  setup do
    @user = users(:family_admin)
    login_as(@user)
  end

  test "sidebar shows consent if ai is disabled for user" do
    @user.update!(ai_enabled: false)

    visit root_path

    within "#chat-container" do
      assert_selector "h3", text: "Enable Maybe AI"
    end
  end

  test "sidebar shows index when enabled and chats are empty" do
    @user.update!(ai_enabled: true)
    @user.chats.destroy_all

    visit root_url

    within "#chat-container" do
      assert_selector "h1", text: "Chats"
    end
  end

  test "sidebar shows last viewed chat" do
    @user.update!(ai_enabled: true)

    # First navigate to chats index to see the chat list
    find("#chat-nav-back").click

    # Click on the first chat
    click_on @user.chats.first.title

    # Page refresh
    visit root_url

    # After page refresh, we're still on the last chat we were viewing
    within "#chat-container" do
      assert_selector "h1", text: @user.chats.first.title
    end
  end

  test "create chat and navigate chats sidebar" do
    @user.chats.destroy_all

    visit root_url

    Chat.any_instance.expects(:ask_assistant_later).once

    within "#chat-form" do
      fill_in "chat[content]", with: "Can you help with my finances?"
      find("button[type='submit']").click
    end

    assert_text "Can you help with my finances?"

    find("#chat-nav-back").click

    assert_selector "h1", text: "Chats"

    click_on @user.chats.reload.first.title

    assert_text "Can you help with my finances?"
  end

  test "sidebar is hidden when OpenAI token is missing in self-hosted mode" do
    with_self_hosting do
      with_env_overrides("OPENAI_ACCESS_TOKEN" => nil) do
        visit root_path

        # Sidebar should not be present
        assert_no_selector "#chat-container"

        # Mobile navigation should not include assistant link
        assert_no_link "Assistant"

        # Panel right button should not be present
        assert_no_selector "[data-action='app-layout#toggleRightSidebar']"
      end
    end
  end

  test "sidebar is shown when OpenAI token is present in self-hosted mode" do
    with_self_hosting do
      with_env_overrides("OPENAI_ACCESS_TOKEN" => "test-token") do
        visit root_path

        # Sidebar should be present
        assert_selector "#chat-container"

        # Panel right button should be present
        assert_selector "[data-action='app-layout#toggleRightSidebar']"
      end
    end
  end

  test "sidebar is shown in managed mode regardless of OpenAI token" do
    # Test managed mode (default mode) - should show sidebar even without OpenAI token
    with_env_overrides("OPENAI_ACCESS_TOKEN" => nil) do
      visit root_path

      # Sidebar should still be present in managed mode
      assert_selector "#chat-container"

      # Panel right button should be present
      assert_selector "[data-action='app-layout#toggleRightSidebar']"
    end
  end
end
