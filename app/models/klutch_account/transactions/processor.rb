class KlutchAccount::Transactions::Processor
  def initialize(klutch_account)
    @klutch_account = klutch_account
  end

  def process
    transactions.each do |transaction|
      KlutchEntry::Processor.new(
        transaction,
        klutch_account: klutch_account
      ).process
    end
  end

  private
    attr_reader :klutch_account

    def transactions
      klutch_account.raw_transactions_payload["transactions"] || []
    end
end
