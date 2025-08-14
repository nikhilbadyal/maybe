module Periodable
  extend ActiveSupport::Concern

  included do
    before_action :set_period
  end

  private
    def set_period
      # Support custom period via explicit start_date/end_date params
      if params[:period] == "custom"
        begin
          # Require both start and end dates
          raise ArgumentError unless params[:start_date].present? && params[:end_date].present?

          start_date = Date.parse(params[:start_date])
          end_date = Date.parse(params[:end_date])
          @period = Period.custom(start_date: start_date, end_date: end_date)
          return
        rescue ArgumentError, ActiveModel::ValidationError
          # Fallback below for invalid dates or invalid date range
          flash.now[:alert] = "The custom date range you provided is invalid. Please select a valid start and end date."
          # Clear the period param so we respect the user's default period downstream
          params.delete(:period)
        end
      end

      @period = Period.from_key(params[:period] || Current.user&.default_period)
    rescue Period::InvalidKeyError
      @period = Period.last_30_days
    end
end
