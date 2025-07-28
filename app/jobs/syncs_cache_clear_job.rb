class SyncsCacheClearJob < ApplicationJob
  queue_as :high_priority

  def perform(family)
    syncs = family.syncs
    syncs.where(status: [ "pending", "syncing" ]).update_all(status: "failed")
  end
end
