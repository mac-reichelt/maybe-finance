class KlutchAccount < ApplicationRecord
  belongs_to :klutch_item

  has_one :account, dependent: :destroy

  validates :name, :currency, presence: true

  def upsert_klutch_snapshot!(card_name:, balance:)
    assign_attributes(
      name: card_name,
      current_balance: balance
    )

    save!
  end

  def upsert_klutch_transactions_snapshot!(transactions)
    assign_attributes(
      raw_transactions_payload: { "transactions" => transactions }
    )

    save!
  end
end
