class KlutchItem::Importer
  MAX_HISTORY_DAYS = 90

  def initialize(klutch_item, klutch_provider:)
    @klutch_item = klutch_item
    @klutch_provider = klutch_provider
  end

  def import
    transactions = fetch_transactions
    import_account(transactions)
  rescue StandardError => e
    handle_error(e)
  end

  private
    attr_reader :klutch_item, :klutch_provider

    def handle_error(error)
      if error.message.include?("401") || error.message.include?("403") || error.message.include?("authentication")
        klutch_item.update!(status: :requires_update)
      else
        raise error
      end
    end

    def fetch_transactions
      start_date = MAX_HISTORY_DAYS.days.ago
      end_date = Time.current

      klutch_provider.get_transactions(
        start_date: start_date,
        end_date: end_date
      )
    end

    def import_account(transactions)
      klutch_item.update!(raw_payload: { "transactions" => transactions })

      KlutchItem.transaction do
        klutch_account = klutch_item.klutch_accounts.find_or_initialize_by(
          klutch_id: "klutch_#{klutch_item.id}"
        )

        KlutchAccount::Importer.new(
          klutch_account,
          card_name: klutch_item.name,
          transactions: transactions
        ).import
      end
    end
end
