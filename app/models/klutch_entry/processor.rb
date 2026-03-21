class KlutchEntry::Processor
  def initialize(klutch_transaction, klutch_account:)
    @klutch_transaction = klutch_transaction
    @klutch_account = klutch_account
  end

  def process
    return if skip?

    KlutchAccount.transaction do
      entry = account.entries.find_or_initialize_by(klutch_id: klutch_id) do |e|
        e.entryable = Transaction.new
      end

      entry.assign_attributes(
        amount: amount,
        currency: currency,
        date: date,
        notes: notes
      )

      entry.enrich_attribute(
        :name,
        name,
        source: "klutch"
      )

      entry.save!

      apply_card_tag(entry)
    end
  end

  private
    attr_reader :klutch_transaction, :klutch_account

    def account
      klutch_account.account
    end

    def skip?
      klutch_transaction["amount"].to_d.zero? || klutch_transaction["transactionDate"].blank?
    end

    def klutch_id
      klutch_transaction["id"]
    end

    def name
      if klutch_transaction["transactionType"] == "PAYMENT"
        "Payment – #{klutch_transaction['merchantName'] || 'Card Payment'}"
      else
        klutch_transaction["merchantName"] || "Unknown"
      end
    end

    def amount
      abs_amount = klutch_transaction["amount"].to_d.abs

      # In Maybe, positive amounts = outflows (debits/charges)
      # CHARGE = money spent = positive (outflow)
      # PAYMENT = money paid to card = negative (inflow)
      if klutch_transaction["transactionType"] == "PAYMENT"
        -abs_amount
      else
        abs_amount
      end
    end

    def currency
      klutch_account.currency
    end

    def date
      date_str = klutch_transaction["transactionDate"]
      Date.parse(date_str)
    rescue Date::Error, TypeError
      Date.current
    end

    def notes
      parts = []

      mcc = klutch_transaction["mcc"]
      if mcc.present?
        parts << "MCC: #{mcc['code']} – #{mcc['description']}" if mcc["code"].present?
      end

      card = klutch_transaction["card"]
      parts << "Card: #{card['name']}" if card&.dig("name").present?

      category = klutch_transaction.dig("category", "name")
      parts << "Category: #{category.gsub('_', ' ').titleize}" if category.present?

      parts.join("\n").presence
    end

    def apply_card_tag(entry)
      card_name = klutch_transaction.dig("card", "name")
      return unless card_name.present?

      family = klutch_account.klutch_item.family
      tag = family.tags.find_or_create_by!(name: card_name)

      unless entry.entryable.tags.include?(tag)
        entry.entryable.tags << tag
      end
    end
end
