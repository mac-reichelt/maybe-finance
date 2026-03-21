module Family::KlutchConnectable
  extend ActiveSupport::Concern

  included do
    has_many :klutch_items, dependent: :destroy
  end

  def can_connect_klutch?
    true
  end

  def create_klutch_item!(endpoint:, client_id:, secret_key:, item_name: "Klutch Card")
    # Validate credentials by attempting authentication
    provider = Provider::Klutch.new(
      endpoint: endpoint,
      client_id: client_id,
      secret_key: secret_key
    )
    provider.authenticate

    klutch_item = klutch_items.create!(
      name: item_name,
      endpoint: endpoint,
      client_id: client_id,
      secret_key: secret_key
    )

    klutch_item.sync_later

    klutch_item
  end
end
