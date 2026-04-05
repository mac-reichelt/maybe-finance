class KlutchAccount::Processor
  attr_reader :klutch_account

  def initialize(klutch_account)
    @klutch_account = klutch_account
  end

  def process
    process_account!
    process_transactions
  end

  private

    def family
      klutch_account.klutch_item.family
    end

    def process_account!
      KlutchAccount.transaction do
        account = family.accounts.find_or_initialize_by(
          klutch_account_id: klutch_account.id
        )

        balance = (klutch_account.current_balance || 0).abs

        account.enrich_attributes(
          {
            name: klutch_account.name,
            subtype: "credit_card"
          },
          source: "klutch"
        )

        account.assign_attributes(
          accountable: CreditCard.new,
          balance: balance,
          currency: klutch_account.currency,
          cash_balance: balance
        )

        account.save!

        account.set_current_balance(balance)
      end
    end

    def process_transactions
      KlutchAccount::Transactions::Processor.new(klutch_account).process
    rescue => e
      Rails.logger.error("Klutch transaction processing failed for account #{klutch_account.id}: #{e.message}")
      Sentry.capture_exception(e) if defined?(Sentry)
    end
end
