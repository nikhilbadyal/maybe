class Import::UploadsController < ApplicationController
  layout "imports"

  before_action :set_import

  def show
    @sorted_accounts = sorted_accounts
  end

  def sample_csv
    send_data @import.csv_template.to_csv,
      filename: "#{@import.type.underscore.split('_').first}_sample.csv",
      type: "text/csv",
      disposition: "attachment"
  end

  def update
    if csv_valid?(csv_str)
      @import.account = Current.family.accounts.find_by(id: params.dig(:import, :account_id))
      @import.assign_attributes(raw_file_str: csv_str, col_sep: upload_params[:col_sep])
      @import.save!(validate: false)

      redirect_to import_configuration_path(@import, template_hint: true), notice: "CSV uploaded successfully."
    else
      @sorted_accounts = sorted_accounts
      flash.now[:alert] = "Must be valid CSV with headers and at least one row of data"

      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_import
      @import = Current.family.imports.find(params[:import_id])
    end

    def csv_str
      @csv_str ||= upload_params[:csv_file]&.read || upload_params[:raw_file_str]
    end

    def csv_valid?(str)
      begin
        csv = Import.parse_csv_str(str, col_sep: upload_params[:col_sep])
        return false if csv.headers.empty?
        return false if csv.count == 0
        true
      rescue CSV::MalformedCSVError
        false
      end
    end

    def upload_params
      params.require(:import).permit(:raw_file_str, :csv_file, :col_sep)
    end

    def sorted_accounts
      sort_by = Current.user&.balance_sheet_sort || BalanceSheet::Sorter::DEFAULT_SORT
      order_clause = if sort_by.start_with?("balance_")
        direction = sort_by.end_with?("_asc") ? :asc : :desc
        { balance: direction }
      else
        Arel.sql(BalanceSheet::Sorter.for(sort_by).order_clause)
      end
      @import.family.accounts.visible.order(order_clause)
    end
end
