module PagesHelper
  def download_net_worth_data_link_params(period)
    params = { format: :csv, period: period.key }
    if period.key == "custom"
      params[:start_date] = period.start_date
      params[:end_date] = period.end_date
    end
    params
  end
end
