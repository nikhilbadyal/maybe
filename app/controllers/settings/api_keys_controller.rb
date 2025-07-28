# frozen_string_literal: true

class Settings::ApiKeysController < ApplicationController
  layout "settings"

  before_action :set_api_key, only: [ :show, :destroy ]

  def show
    @current_api_key = @api_key
  end

  def new
    # Allow regeneration by not redirecting if user explicitly wants to create a new key
    # Only redirect if user stumbles onto new page without explicit intent
    redirect_to settings_api_key_path if Current.user.api_keys.active.exists? && !params[:regenerate]
    @api_key = ApiKey.new
  end

  def create
    @plain_key = ApiKey.generate_secure_key
    @api_key = Current.user.api_keys.build(api_key_params)
    @api_key.key = @plain_key

    # Temporarily revoke existing keys for validation to pass
    existing_keys = Current.user.api_keys.active
    existing_keys.each { |key| key.update_column(:revoked_at, Time.current) }

    if @api_key.save
      flash[:notice] = "Your API key has been created successfully"
      redirect_to settings_api_key_path
    else
      # Restore existing keys if new key creation failed
      existing_keys.each { |key| key.update_column(:revoked_at, nil) }
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if @api_key&.revoke!
      flash[:notice] = "API key has been revoked successfully"
    else
      flash[:alert] = "Failed to revoke API key"
    end
    redirect_to settings_api_key_path
  end

  private

    def set_api_key
      @api_key = Current.user.api_keys.active.first

      # Proactively trigger decryption to catch the error here. This prevents the
      # error from being raised in the view, which is harder to rescue from. If
      # this before_action redirects, the `show` action will not be executed.
      @api_key&.plain_key
    rescue ActiveRecord::Encryption::Errors::Decryption
      key_id_to_revoke = @api_key&.id
      if key_id_to_revoke
        ApiKey.where(id: key_id_to_revoke).update_all(revoked_at: Time.current)
        flash[:alert] = "We were unable to decrypt your existing API key. It has been revoked. Please generate a new one."
      else
        flash[:alert] = "An error occurred with your API key. Please generate a new one."
      end
      redirect_to new_settings_api_key_path(regenerate: true)
    end

    def api_key_params
      # Convert single scope value to array for storage
      permitted_params = params.require(:api_key).permit(:name, :scopes)
      if permitted_params[:scopes].present?
        permitted_params[:scopes] = [ permitted_params[:scopes] ]
      end
      permitted_params
    end
end
