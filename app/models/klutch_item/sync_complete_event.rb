class KlutchItem::SyncCompleteEvent
  attr_reader :klutch_item

  def initialize(klutch_item)
    @klutch_item = klutch_item
  end

  def broadcast
    klutch_item.accounts.each do |account|
      account.broadcast_sync_complete
    end

    klutch_item.broadcast_replace_to(
      klutch_item.family,
      target: "klutch_item_#{klutch_item.id}",
      partial: "klutch_items/klutch_item",
      locals: { klutch_item: klutch_item }
    )

    klutch_item.family.broadcast_sync_complete
  end
end
