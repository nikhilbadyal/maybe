# frozen_string_literal: true

class Api::V1::MessagesController < Api::V1::BaseController
  resource_description do
    short "API for managing messages within a chat"
    formats [ "json" ]
    api_version "v1"
  end

  before_action :require_ai_enabled
  before_action :ensure_write_scope, only: [ :create, :retry ]
  before_action :set_chat

  api :POST, "/chats/:chat_id/messages", "Create a new message in a chat"
  param :chat_id, String, desc: "ID of the chat to add the message to", required: true
  param :content, String, desc: "Content of the user message", required: true
  param :model, String, desc: "AI model to use (e.g., 'gpt-4', 'gpt-3.5-turbo', defaults to 'gpt-4')", required: false
  returns code: 201, desc: "Successfully created message" do
    property :id, String, desc: "Message ID"
    property :chat_id, String, desc: "Associated Chat ID"
    property :type, String, desc: "Type of message (UserMessage)"
    property :role, String, desc: "Role of the message sender (user)"
    property :content, String, desc: "Content of the message"
    property :created_at, DateTime, desc: "Message creation timestamp"
    property :updated_at, DateTime, desc: "Message last updated timestamp"
    property :ai_response_status, String, desc: "Status of AI response generation"
    property :ai_response_message, String, desc: "Message about AI response status"
  end
  returns code: 404, desc: "Chat not found"
  returns code: 422, desc: "Failed to create message"
  def create
    @message = @chat.messages.build(
      content: message_params[:content],
      type: "UserMessage",
      ai_model: message_params[:model] || "gpt-4"
    )

    if @message.save
      AssistantResponseJob.perform_later(@message)
      render :show, status: :created
    else
      render json: { error: "Failed to create message", details: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  api :POST, "/chats/:chat_id/messages/retry", "Retry the last assistant message in a chat"
  param :chat_id, String, desc: "ID of the chat to retry the message in", required: true
  returns code: 202, desc: "Retry initiated successfully" do
    property :message, String, desc: "Confirmation message"
    property :message_id, String, desc: "ID of the new assistant message created for the retry"
  end
  returns code: 404, desc: "Chat not found"
  returns code: 422, desc: "No assistant message to retry"
  def retry
    last_message = @chat.messages.ordered.last

    if last_message&.type == "AssistantMessage"
      new_message = @chat.messages.create!(
        type: "AssistantMessage",
        content: "",
        ai_model: last_message.ai_model
      )

      AssistantResponseJob.perform_later(new_message)
      render json: { message: "Retry initiated", message_id: new_message.id }, status: :accepted
    else
      render json: { error: "No assistant message to retry" }, status: :unprocessable_entity
    end
  end

  private

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def set_chat
      @chat = Current.user.chats.find(params[:chat_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Chat not found" }, status: :not_found
    end

    def message_params
      params.permit(:content, :model)
    end
end
