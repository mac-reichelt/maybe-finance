class SimplefinItem::Importer
  MAX_HISTORY_DAYS = 730

  def initialize(simplefin_item, simplefin_provider:)
    @simplefin_item = simplefin_item
    @simplefin_provider = simplefin_provider
  end

  def import
    data = fetch_accounts_data
    import_accounts(data)
  rescue StandardError => e
    handle_error(e)
  end

  private
    attr_reader :simplefin_item, :simplefin_provider

    def handle_error(error)
      if error.message.include?("403") || error.message.include?("401")
        simplefin_item.update!(status: :requires_update)
      else
        raise error
      end
    end

    def fetch_accounts_data
      start_date = MAX_HISTORY_DAYS.days.ago.to_date
      simplefin_provider.get_accounts(start_date: start_date)
    end

    def import_accounts(data)
      simplefin_item.update!(raw_payload: data)

      accounts = data.dig("accounts") || []

      SimplefinItem.transaction do
        accounts.each do |raw_account|
          account_id = raw_account["id"]

          simplefin_account = simplefin_item.simplefin_accounts.find_or_initialize_by(
            simplefin_id: account_id
          )

          SimplefinAccount::Importer.new(
            simplefin_account,
            account_data: raw_account
          ).import
        end
      end
    end
end
