class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_authentication

  def plaid
    webhook_body = request.body.read
    plaid_verification_header = request.headers["Plaid-Verification"]

    client = Provider::Plaid.new(Rails.application.config.plaid, region: :us)

    client.validate_webhook!(plaid_verification_header, webhook_body)
    client.process_webhook(webhook_body)

    render json: { received: true }, status: :ok
  rescue => error
    Sentry.capture_exception(error)
    render json: { error: "Invalid webhook: #{error.message}" }, status: :bad_request
  end

  def plaid_eu
    webhook_body = request.body.read
    plaid_verification_header = request.headers["Plaid-Verification"]

    client = Provider::Plaid.new(Rails.application.config.plaid_eu, region: :eu)

    client.validate_webhook!(plaid_verification_header, webhook_body)
    client.process_webhook(webhook_body)

    render json: { received: true }, status: :ok
  rescue => error
    Sentry.capture_exception(error)
    render json: { error: "Invalid webhook: #{error.message}" }, status: :bad_request
  end

  def stripe
    webhook_body = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    client = Stripe::StripeClient.new(ENV["STRIPE_SECRET_KEY"])

    begin
      thin_event = client.parse_thin_event(webhook_body, sig_header, ENV["STRIPE_WEBHOOK_SECRET"])

      event = client.v1.events.retrieve(thin_event.id)

      case event.type
      when /^customer\.subscription\./
        handle_subscription_event(event)
      when "customer.created", "customer.updated", "customer.deleted"
        handle_customer_event(event)
      else
        Rails.logger.info "Unhandled event type: #{event.type}"
      end

    rescue JSON::ParserError => error
      Sentry.capture_exception(error)
      render json: { error: "Invalid payload" }, status: :bad_request
      return
    rescue Stripe::SignatureVerificationError => error
      Sentry.capture_exception(error)
      render json: { error: "Invalid signature" }, status: :bad_request
      return
    end

    render json: { received: true }, status: :ok
  end

  private

    def handle_subscription_event(event)
      subscription = event.data.object
      family = Family.find_by(stripe_customer_id: subscription.customer)

      if family
        family.update(
          stripe_plan_id: subscription.plan.id,
          stripe_subscription_status: subscription.status
        )
      else
        Rails.logger.error "Family not found for Stripe customer ID: #{subscription.customer}"
      end
    end

    def handle_customer_event(event)
      customer = event.data.object
      family = Family.find_by(stripe_customer_id: customer.id)

      if family
        family.update(stripe_customer_id: customer.id)
      else
        Rails.logger.error "Family not found for Stripe customer ID: #{customer.id}"
      end
    end
end
