class Family::SyncCompleteEvent
  attr_reader :family

  def initialize(family)
    @family = family
  end

  # Broadcasts a page refresh to all browsers subscribed to the family's updates.
  # Instead of selectively replacing parts of the dashboard with hardcoded defaults
  # (which previously forced the Net Worth chart to reset to 30D, ignoring user default
  # or currently selected period preferences), this triggers a full Turbo 8 page
  # refresh. Turbo morphs the body to the fresh data, preserving user interaction
  # state, selected period filters, and page context across the entire app.
  def broadcast
    family.broadcast_refresh
  end
end
