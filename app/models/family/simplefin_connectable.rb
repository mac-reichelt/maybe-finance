module Family::SimplefinConnectable
  extend ActiveSupport::Concern

  included do
    has_many :simplefin_items, dependent: :destroy
  end

  def can_connect_simplefin?
    true # SimpleFIN only requires a setup token from the user, no server-side config needed
  end

  def create_simplefin_item!(setup_token:, item_name: "SimpleFIN")
    access_url = Provider::Simplefin.claim_setup_token(setup_token)

    simplefin_item = simplefin_items.create!(
      name: item_name,
      access_url: access_url
    )

    simplefin_item.sync_later

    simplefin_item
  end
end
