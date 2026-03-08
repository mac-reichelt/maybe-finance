class SimplefinAccount::Processor
  include SimplefinAccount::TypeMappable

  attr_reader :simplefin_account

  def initialize(simplefin_account)
    @simplefin_account = simplefin_account
  end

  def process
    process_account!
    process_transactions
  end

  private

  def family
    simplefin_account.simplefin_item.family
  end

  def process_account!
    SimplefinAccount.transaction do
      account = family.accounts.find_or_initialize_by(
        simplefin_account_id: simplefin_account.id
      )

      balance = (simplefin_account.current_balance || simplefin_account.available_balance || 0).abs

      account.enrich_attributes(
        {
          name: simplefin_account.name,
          subtype: map_subtype(simplefin_account.account_type)
        },
        source: "simplefin"
      )

      account.assign_attributes(
        accountable: map_accountable(simplefin_account.account_type),
        balance: balance,
        currency: simplefin_account.currency,
        cash_balance: balance
      )

      account.save!

      account.set_current_balance(balance)
    end
  end

  def process_transactions
    SimplefinAccount::Transactions::Processor.new(simplefin_account).process
  rescue => e
    Rails.logger.error("SimpleFIN transaction processing failed for account #{simplefin_account.id}: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end
