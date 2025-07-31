namespace :accounts do
  desc "Migrate an account from OtherAsset to Depository. Usage: rails accounts:migrate_to_depository[account_id] or rails accounts:migrate_to_depository[all]"
  task :migrate_to_depository, [ :scope ] => :environment do |_, args|
    scope = args[:scope]

    if scope == "all"
      accounts = Account.where(accountable_type: "OtherAsset")
      puts "Found #{accounts.count} OtherAsset accounts to migrate."
    elsif scope.present?
      account = Account.find_by(id: scope)

      if account.nil?
        puts "Account with ID #{scope} not found."
        exit
      end

      if account.accountable_type != "OtherAsset"
        puts "Account is not an OtherAsset account. It is a #{account.accountable_type}."
        exit
      end
      accounts = [ account ]
    else
      puts "Please provide an account_id or 'all'. Usage: rails \"accounts:migrate_to_depository[your_account_id]\" or rails \"accounts:migrate_to_depository[all]\""
      exit
    end

    accounts.each do |account|
      puts "Migrating account #{account.name} (ID: #{account.id}) from OtherAsset to Depository..."

      ActiveRecord::Base.transaction do
        old_accountable = account.accountable
        new_accountable = Depository.create!
        account.update!(accountable: new_accountable)
        old_accountable.destroy!

        puts "Migration complete for account #{account.id}. The account is now a Depository account."
      end
    end
    puts "All migrations complete. Please re-sync the accounts to update their balances."
  end
end
