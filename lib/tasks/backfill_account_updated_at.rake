namespace :data_migrations do
  desc "Backfill account updated_at timestamps based on the latest entry"
  task backfill_account_updated_at: :environment do
    puts "Starting to backfill account updated_at timestamps..."

    Account.find_in_batches do |accounts|
      accounts.each do |account|
        latest_entry_created_at = account.entries.order(created_at: :desc).limit(1).pick(:created_at)

        if latest_entry_created_at.present? && latest_entry_created_at > account.updated_at
          puts "Updating account #{account.id} (#{account.name}) to #{latest_entry_created_at}"
          account.update_column(:updated_at, latest_entry_created_at)
        end
      end
    end

    puts "Finished backfilling account updated_at timestamps."
  end
end
