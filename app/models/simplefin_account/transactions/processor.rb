class SimplefinAccount::Transactions::Processor
  def initialize(simplefin_account)
    @simplefin_account = simplefin_account
  end

  def process
    transactions.each do |transaction|
      SimplefinEntry::Processor.new(
        transaction,
        simplefin_account: simplefin_account
      ).process
    end
  end

  private
    attr_reader :simplefin_account

    def account
      simplefin_account.account
    end

    def transactions
      simplefin_account.raw_transactions_payload["transactions"] || []
    end
end
