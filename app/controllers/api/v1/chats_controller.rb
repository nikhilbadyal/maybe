# frozen_string_literal: true

class Api::V1::ChatsController < Api::V1::BaseController
  include Pagy::Backend

  resource_description do
    short "AI-powered chat management"
    formats [ "json" ]
    api_version "v1"
    tags "ai", "chats", "assistant"
    description <<-EOS
      ## AI Chat Management

      Create and manage AI-powered conversations for financial insights and assistance.
      Requires AI features to be enabled for the user account.

      ### Chat Features
      - **Multi-turn conversations** with AI assistant
      - **Contextual responses** based on user's financial data
      - **Message history** with pagination
      - **Custom AI models** support (GPT-4, GPT-3.5-turbo)

      ### Rate Limiting
      AI chat endpoints may have additional rate limiting based on usage tier.
    EOS
    meta module: "AI Features", priority: "medium"
  end

  before_action :require_ai_enabled
  before_action :ensure_read_scope, only: [ :index, :show ]
  before_action :ensure_write_scope, only: [ :create, :update, :destroy ]
  before_action :set_chat, only: [ :show, :update, :destroy ]

  api :GET, "/chats", "List all AI chats"
  param_group :pagination_params, Api::V1::BaseController
  tags "ai", "chats", "list"
  returns code: 200, desc: "Successfully retrieved chats list" do
    property :chats, array_of: Hash, desc: "Array of chat objects" do
      property :id, String, desc: "Chat ID", example: "chat_123e4567"
      property :title, String, desc: "Chat title", example: "Budget Analysis Discussion"
      property :last_message_at, DateTime, desc: "Last message timestamp", example: "2024-01-20T14:45:00Z"
      property :message_count, Integer, desc: "Number of messages", example: 8
      property :error, String, desc: "Error message if any", example: nil
      property :created_at, DateTime, desc: "Chat creation timestamp", example: "2024-01-15T10:30:00Z"
      property :updated_at, DateTime, desc: "Last update timestamp", example: "2024-01-20T14:45:00Z"
    end
    param_group :pagination_response, Api::V1::BaseController
  end
  example <<-EOS
    {
      "chats": [
        {
          "id": "chat_123e4567",
          "title": "Budget Analysis Discussion",
          "last_message_at": "2024-01-20T14:45:00Z",
          "message_count": 8,
          "error": null,
          "created_at": "2024-01-15T10:30:00Z",
          "updated_at": "2024-01-20T14:45:00Z"
        }
      ],
      "pagination": {
        "page": 1,
        "per_page": 20,
        "total_count": 5,
        "total_pages": 1
      }
    }
  EOS
  def index
    @pagy, @chats = pagy(Current.user.chats.ordered, items: 20)
  end

  api :GET, "/chats/:id", "Retrieve a chat with its messages"
  param :id, String, desc: "Chat ID to retrieve", required: true, example: "chat_123e4567"
  tags "ai", "chats", "details"
  returns code: 200, desc: "Successfully retrieved chat with messages" do
    property :id, String, desc: "Chat ID", example: "chat_123e4567"
    property :title, String, desc: "Chat title", example: "Budget Analysis Discussion"
    property :error, String, desc: "Error message if any", example: nil
    property :created_at, DateTime, desc: "Chat creation timestamp", example: "2024-01-15T10:30:00Z"
    property :updated_at, DateTime, desc: "Last update timestamp", example: "2024-01-20T14:45:00Z"
    property :messages, array_of: Hash, desc: "Chat messages" do
      property :id, String, desc: "Message ID", example: "msg_123e4567"
      property :type, String, desc: "Message type", example: "user_message"
      property :role, [ "user", "assistant" ], desc: "Message sender role", example: "user"
      property :content, String, desc: "Message content", example: "Can you analyze my spending?"
      property :created_at, DateTime, desc: "Message timestamp", example: "2024-01-15T10:30:00Z"
      property :updated_at, DateTime, desc: "Last update timestamp", example: "2024-01-15T10:30:00Z"
      property :model, String, desc: "AI model used (for assistant messages)", example: "gpt-4"
      property :tool_calls, Array, of: Hash, desc: "Tool calls made (for assistant messages)", example: []
    end
    param_group :pagination_response, Api::V1::BaseController
  end
  returns code: 404, desc: "Chat not found"
  def show
    return unless @chat
    @pagy, @messages = pagy(@chat.messages.ordered, items: 50)
  end

  api :POST, "/chats", "Create a new AI chat"
  description <<-EOS
    Create a new AI chat conversation. Optionally include an initial message
    to start the conversation immediately.
  EOS
  param :title, String, desc: "Optional chat title", required: false, example: "Budget Analysis"
  param :message, String, desc: "Initial message to start conversation", required: false, example: "Can you help me analyze my spending?"
  param :model, [ "gpt-4", "gpt-3.5-turbo" ], desc: "AI model to use", required: false, example: "gpt-4"
  tags "ai", "chats", "create"
  returns code: 201, desc: "Successfully created chat" do
    property :id, String, desc: "Chat ID", example: "chat_123e4567"
    property :title, String, desc: "Chat title", example: "Budget Analysis"
    property :error, String, desc: "Error message if any", example: nil
    property :created_at, DateTime, desc: "Chat creation timestamp", example: "2024-01-15T10:30:00Z"
    property :updated_at, DateTime, desc: "Last update timestamp", example: "2024-01-15T10:30:00Z"
    property :messages, array_of: Hash, desc: "Initial messages (if provided)", example: []
  end
  returns code: 422, desc: "Failed to create chat or initial message"
  example <<-EOS
    Request:
    {
      "title": "Budget Analysis",
      "message": "Can you help me analyze my spending patterns?",
      "model": "gpt-4"
    }

    Response:
    {
      "id": "chat_123e4567",
      "title": "Budget Analysis",
      "error": null,
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z",
      "messages": [
        {
          "id": "msg_123e4567",
          "type": "user_message",
          "role": "user",
          "content": "Can you help me analyze my spending patterns?",
          "created_at": "2024-01-15T10:30:00Z",
          "updated_at": "2024-01-15T10:30:00Z",
          "model": "gpt-4",
          "tool_calls": []
        }
      ]
    }
  EOS
  def create
    @chat = Current.user.chats.build(title: chat_params[:title])

    if @chat.save
      if chat_params[:message].present?
        @message = @chat.messages.build(
          content: chat_params[:message],
          type: "UserMessage",
          ai_model: chat_params[:model] || "gpt-4"
        )

        if @message.save
          AssistantResponseJob.perform_later(@message)
          render :show, status: :created
        else
          @chat.destroy
          render json: { error: "Failed to create initial message", details: @message.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render :show, status: :created
      end
    else
      render json: { error: "Failed to create chat", details: @chat.errors.full_messages }, status: :unprocessable_entity
    end
  end

  api :PATCH, "/chats/:id", "Update a chat's title"
  param :id, String, desc: "Chat ID to update", required: true, example: "chat_123e4567"
  param :title, String, desc: "New chat title", required: true, example: "Updated Budget Analysis"
  tags "ai", "chats", "update"
  returns code: 200, desc: "Successfully updated chat"
  returns code: 404, desc: "Chat not found"
  returns code: 422, desc: "Failed to update chat"
  def update
    return unless @chat

    if @chat.update(update_chat_params)
      render :show
    else
      render json: { error: "Failed to update chat", details: @chat.errors.full_messages }, status: :unprocessable_entity
    end
  end

  api :DELETE, "/chats/:id", "Delete a chat"
  param :id, String, desc: "Chat ID to delete", required: true, example: "chat_123e4567"
  tags "ai", "chats", "delete"
  returns code: 204, desc: "Successfully deleted chat (no content)"
  returns code: 404, desc: "Chat not found"
  def destroy
    return unless @chat
    @chat.destroy
    head :no_content
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def set_chat
      @chat = Current.user.chats.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Chat not found" }, status: :not_found
    end

    def chat_params
      params.permit(:title, :message, :model)
    end

    def update_chat_params
      params.permit(:title)
    end
end
