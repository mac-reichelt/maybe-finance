class KlutchAccount::Importer
  def initialize(klutch_account, card_name:, transactions:)
    @klutch_account = klutch_account
    @card_name = card_name
    @transactions = transactions
  end

  def import
    import_account_info
    import_transactions if transactions.present?
  end

  private
    attr_reader :klutch_account, :card_name, :transactions

    def import_account_info
      # Calculate balance from settled charges minus payments
      balance = calculate_balance

      klutch_account.upsert_klutch_snapshot!(
        card_name: card_name,
        balance: balance
      )
    end

    def import_transactions
      klutch_account.upsert_klutch_transactions_snapshot!(transactions)
    end

    def calculate_balance
      transactions.sum do |txn|
        amount = txn["amount"].to_d
        case txn["transactionType"]
        when "PAYMENT"
          -amount.abs # Payments reduce balance
        else
          amount.abs # Charges increase balance
        end
      end
    end
end
