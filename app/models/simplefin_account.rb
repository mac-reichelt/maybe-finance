class SimplefinAccount < ApplicationRecord
  belongs_to :simplefin_item

  has_one :account, dependent: :destroy

  validates :name, :currency, presence: true

  validate :has_balance

  def upsert_simplefin_snapshot!(account_data)
    assign_attributes(
      current_balance: account_data["balance"].to_d,
      available_balance: account_data["available-balance"]&.to_d,
      currency: account_data["currency"]&.upcase || "USD",
      account_type: classify_account_type(account_data),
      name: account_data["name"],
      org_name: account_data.dig("org", "name"),
      org_url: account_data.dig("org", "url"),
      raw_payload: account_data
    )

    save!
  end

  def upsert_simplefin_transactions_snapshot!(transactions)
    assign_attributes(
      raw_transactions_payload: { "transactions" => transactions }
    )

    save!
  end

  private

    def has_balance
      return if !current_balance.nil? || !available_balance.nil?
      errors.add(:base, "SimpleFIN account must have either current or available balance")
    end

    # SimpleFIN doesn't reliably provide account type,
    # so we infer from balance, name, and org heuristics
    def classify_account_type(account_data)
      balance = account_data["balance"].to_d
      name = (account_data["name"] || "").downcase
      org_name = (account_data.dig("org", "name") || "").downcase

      return "credit" if balance < 0
      return "credit" if name.match?(/\b(visa|mastercard|credit\s*card|store\s*card|amex)\b/i)
      return "credit" if org_name.match?(/credit\s*card/i)

      if name.match?(/\b(savings?|checking|money\s*market)\b/i)
        "depository"
      else
        "depository"
      end
    end
end
