class SimplefinAccount::Importer
  def initialize(simplefin_account, account_data:)
    @simplefin_account = simplefin_account
    @account_data = account_data
  end

  def import
    import_account_info
    import_transactions if transactions.present?
  end

  private
    attr_reader :simplefin_account, :account_data

    def import_account_info
      simplefin_account.upsert_simplefin_snapshot!(account_data)
    end

    def import_transactions
      simplefin_account.upsert_simplefin_transactions_snapshot!(transactions)
    end

    def transactions
      account_data["transactions"] || []
    end
end
