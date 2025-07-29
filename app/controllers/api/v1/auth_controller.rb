module Api
  module V1
    class AuthController < BaseController
      include Invitable

      resource_description do
        short "User authentication and account management"
        formats [ "json" ]
        api_version "v1"
        tags "authentication", "user_management"
        description <<-EOS
          ## Authentication Endpoints

          Handle user registration, login, and token management for the Maybe API.

          ### Authentication Flow
          1. **Register** a new account or **login** with existing credentials
          2. Receive OAuth2 access and refresh tokens
          3. Use access token in `Authorization: Bearer <token>` header
          4. Refresh tokens before expiration using `/auth/refresh`

          ### Security Features
          - Multi-factor authentication (MFA) support
          - Device tracking and management
          - Token refresh mechanism
          - Invite code system for controlled access
        EOS
        meta module: "Authentication", priority: "critical"
      end

      skip_before_action :authenticate_request!
      skip_before_action :check_api_key_rate_limit
      skip_before_action :log_api_access

      api :POST, "/auth/signup", "Register a new user account"
      description <<-EOS
        Create a new user account with email and password. Optionally accepts an invite code
        if the platform requires invitations. Returns OAuth2 tokens for immediate API access.
      EOS
      param :invite_code, String, desc: "Invite code for registration (required if platform uses invites)", required: false, example: "WELCOME2024"
      param :user, Hash, desc: "User registration details", required: true do
        param :email, String, desc: "User's email address", required: true, example: "john.doe@example.com"
        param :password, String, desc: "Password (min 8 chars, must include uppercase, lowercase, number, special char)", required: true, example: "SecurePass123!"
        param :first_name, String, desc: "User's first name", required: true, example: "John"
        param :last_name, String, desc: "User's last name", required: true, example: "Doe"
      end
      param_group :device_info, Api::V1::BaseController
      tags "authentication", "registration"
      returns code: 201, desc: "Successfully registered user and created OAuth tokens" do
        param_group :oauth_token_response, Api::V1::BaseController
        param_group :user_response, Api::V1::BaseController
      end
      returns code: 400, desc: "Bad request - missing device information"
      returns code: 403, desc: "Forbidden - invite code required or invalid"
      returns code: 422, desc: "Validation failed - invalid user data or password requirements"
      example <<-EOS
        Request:
        {
          "invite_code": "WELCOME2024",
          "user": {
            "email": "john.doe@example.com",
            "password": "SecurePass123!",
            "first_name": "John",
            "last_name": "Doe"
          },
          "device": {
            "device_id": "iPhone_12345",
            "device_name": "John's iPhone",
            "device_type": "iOS",#{' '}
            "os_version": "17.1.2",
            "app_version": "1.2.0"
          }
        }

        Response:
        {
          "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
          "refresh_token": "def50200abc123def456...",
          "token_type": "Bearer",
          "expires_in": 2592000,
          "created_at": 1640995200,
          "user": {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "email": "john.doe@example.com",
            "first_name": "John",
            "last_name": "Doe"
          }
        }
      EOS
      def signup
        # Check if invite code is required
        if invite_code_required? && params[:invite_code].blank?
          render json: { error: "Invite code is required" }, status: :forbidden
          return
        end

        # Validate invite code if provided
        if params[:invite_code].present? && !InviteCode.exists?(token: params[:invite_code]&.downcase)
          render json: { error: "Invalid invite code" }, status: :forbidden
          return
        end

        # Validate password
        password_errors = validate_password(params[:user][:password])
        if password_errors.any?
          render json: { errors: password_errors }, status: :unprocessable_entity
          return
        end

        # Validate device info
        unless valid_device_info?
          render json: { error: "Device information is required" }, status: :bad_request
          return
        end

        user = User.new(user_signup_params)

        # Create family for new user
        family = Family.new
        user.family = family
        user.role = :admin

        if user.save
          # Claim invite code if provided
          InviteCode.claim!(params[:invite_code]) if params[:invite_code].present?

          # Create device and OAuth token
          device = create_or_update_device(user)
          token_response = create_oauth_token_for_device(user, device)

          render json: token_response.merge(
            user: {
              id: user.id,
              email: user.email,
              first_name: user.first_name,
              last_name: user.last_name
            }
          ), status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      api :POST, "/auth/login", "Authenticate user and retrieve OAuth tokens"
      description <<-EOS
        Authenticate with email and password to receive OAuth2 access tokens.
        Supports multi-factor authentication (MFA) if enabled for the user.
      EOS
      param :email, String, desc: "User's email address", required: true, example: "john.doe@example.com"
      param :password, String, desc: "User's password", required: true, example: "SecurePass123!"
      param :otp_code, String, desc: "One-time password for MFA (required if user has MFA enabled)", required: false, example: "123456"
      param_group :device_info, Api::V1::BaseController
      tags "authentication", "login"
      returns code: 200, desc: "Successfully authenticated and created OAuth tokens" do
        param_group :oauth_token_response, Api::V1::BaseController
        param_group :user_response, Api::V1::BaseController
      end
      returns code: 400, desc: "Bad request - missing device information"
      returns code: 401, desc: "Unauthorized - invalid credentials or MFA required"
      example <<-EOS
        Request:
        {
          "email": "john.doe@example.com",
          "password": "SecurePass123!",
          "otp_code": "123456",
          "device": {
            "device_id": "iPhone_12345",
            "device_name": "John's iPhone",#{' '}
            "device_type": "iOS",
            "os_version": "17.1.2",
            "app_version": "1.2.0"
          }
        }

        Response (Success):
        {
          "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
          "refresh_token": "def50200abc123def456...",
          "token_type": "Bearer",
          "expires_in": 2592000,
          "created_at": 1640995200,
          "user": {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "email": "john.doe@example.com",
            "first_name": "John",
            "last_name": "Doe"
          }
        }

        Response (MFA Required):
        {
          "error": "Two-factor authentication required",
          "mfa_required": true
        }
      EOS
      def login
        user = User.find_by(email: params[:email])

        if user&.authenticate(params[:password])
          # Check MFA if enabled
          if user.otp_required?
            unless params[:otp_code].present? && user.verify_otp?(params[:otp_code])
              render json: {
                error: "Two-factor authentication required",
                mfa_required: true
              }, status: :unauthorized
              return
            end
          end

          # Validate device info
          unless valid_device_info?
            render json: { error: "Device information is required" }, status: :bad_request
            return
          end

          # Create device and OAuth token
          device = create_or_update_device(user)
          token_response = create_oauth_token_for_device(user, device)

          render json: token_response.merge(
            user: {
              id: user.id,
              email: user.email,
              first_name: user.first_name,
              last_name: user.last_name
            }
          )
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      api :POST, "/auth/refresh", "Refresh OAuth access token"
      description <<-EOS
        Exchange a valid refresh token for a new access token and refresh token pair.
        The old tokens are revoked in the process for security.
      EOS
      param :refresh_token, String, desc: "The refresh token obtained during login or previous refresh", required: true, example: "def50200abc123def456..."
      param_group :device_info, Api::V1::BaseController
      tags "authentication", "token_management"
      returns code: 200, desc: "Successfully refreshed OAuth tokens" do
        param_group :oauth_token_response, Api::V1::BaseController
      end
      returns code: 400, desc: "Bad request - missing refresh token"
      returns code: 401, desc: "Unauthorized - invalid or revoked refresh token"
      example <<-EOS
        Request:
        {
          "refresh_token": "def50200abc123def456...",
          "device": {
            "device_id": "iPhone_12345",
            "device_name": "John's iPhone",
            "device_type": "iOS",
            "os_version": "17.1.2",#{' '}
            "app_version": "1.2.0"
          }
        }

        Response:
        {
          "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
          "refresh_token": "def50200xyz789def012...",
          "token_type": "Bearer",#{' '}
          "expires_in": 2592000,
          "created_at": 1640995800
        }
      EOS
      def refresh
        # Find the refresh token
        refresh_token = params[:refresh_token]

        unless refresh_token.present?
          render json: { error: "Refresh token is required" }, status: :bad_request
          return
        end

        # Find the access token associated with this refresh token
        access_token = Doorkeeper::AccessToken.by_refresh_token(refresh_token)

        if access_token.nil? || access_token.revoked?
          render json: { error: "Invalid refresh token" }, status: :unauthorized
          return
        end

        # Create new access token
        new_token = Doorkeeper::AccessToken.create!(
          application: access_token.application,
          resource_owner_id: access_token.resource_owner_id,
          expires_in: 30.days.to_i,
          scopes: access_token.scopes,
          use_refresh_token: true
        )

        # Revoke old access token
        access_token.revoke

        # Update device last seen
        user = User.find(access_token.resource_owner_id)
        device = user.mobile_devices.find_by(device_id: params[:device][:device_id])
        device&.update_last_seen!

        render json: {
          access_token: new_token.plaintext_token,
          refresh_token: new_token.plaintext_refresh_token,
          token_type: "Bearer",
          expires_in: new_token.expires_in,
          created_at: new_token.created_at.to_i
        }
      end

      private

        def user_signup_params
          params.require(:user).permit(:email, :password, :first_name, :last_name)
        end

        def validate_password(password)
          errors = []

          if password.blank?
            errors << "Password can't be blank"
            return errors
          end

          errors << "Password must be at least 8 characters" if password.length < 8
          errors << "Password must include both uppercase and lowercase letters" unless password.match?(/[A-Z]/) && password.match?(/[a-z]/)
          errors << "Password must include at least one number" unless password.match?(/\d/)
          errors << "Password must include at least one special character" unless password.match?(/[!@#$%^&*(),.?":{}|<>]/)

          errors
        end

        def valid_device_info?
          device = params[:device]
          return false if device.nil?

          required_fields = %w[device_id device_name device_type os_version app_version]
          required_fields.all? { |field| device[field].present? }
        end

        def create_or_update_device(user)
          # Handle both string and symbol keys
          device_data = params[:device].permit(:device_id, :device_name, :device_type, :os_version, :app_version)

          device = user.mobile_devices.find_or_initialize_by(device_id: device_data[:device_id])
          device.update!(device_data.merge(last_seen_at: Time.current))
          device
        end

        def create_oauth_token_for_device(user, device)
          # Create OAuth application for this device if needed
          oauth_app = device.create_oauth_application!

          # Revoke any existing tokens for this device
          device.revoke_all_tokens!

          # Create new access token with 30-day expiration
          access_token = Doorkeeper::AccessToken.create!(
            application: oauth_app,
            resource_owner_id: user.id,
            expires_in: 30.days.to_i,
            scopes: "read_write",
            use_refresh_token: true
          )

          {
            access_token: access_token.plaintext_token,
            refresh_token: access_token.plaintext_refresh_token,
            token_type: "Bearer",
            expires_in: access_token.expires_in,
            created_at: access_token.created_at.to_i
          }
        end
    end
  end
end
