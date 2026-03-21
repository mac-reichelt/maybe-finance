class SimplefinEntry::Processor
  def initialize(simplefin_transaction, simplefin_account:)
    @simplefin_transaction = simplefin_transaction
    @simplefin_account = simplefin_account
  end

  def process
    SimplefinAccount.transaction do
      entry = account.entries.find_or_initialize_by(simplefin_id: simplefin_id) do |e|
        e.entryable = Transaction.new
      end

      entry.assign_attributes(
        amount: amount,
        currency: currency,
        date: date
      )

      entry.enrich_attribute(
        :name,
        name,
        source: "simplefin"
      )
    end
  end

  private
    attr_reader :simplefin_transaction, :simplefin_account

    def account
      simplefin_account.account
    end

    def simplefin_id
      simplefin_transaction["id"]
    end

    def name
      simplefin_transaction["description"] || simplefin_transaction["payee"] || "Unknown"
    end

    def amount
      # SimpleFIN uses positive for credits, negative for debits
      # Maybe uses positive for outflows (debits), so we negate
      -simplefin_transaction["amount"].to_d
    end

    def currency
      simplefin_account.currency
    end

    def date
      timestamp = simplefin_transaction["posted"]
      if timestamp
        Time.at(timestamp).to_date
      else
        Date.current
      end
    end
end
