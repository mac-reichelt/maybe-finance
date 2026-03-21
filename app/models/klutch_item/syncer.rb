class KlutchItem::Syncer
  attr_reader :klutch_item

  def initialize(klutch_item)
    @klutch_item = klutch_item
  end

  def perform_sync(sync)
    klutch_item.import_latest_klutch_data

    klutch_item.process_accounts

    klutch_item.schedule_account_syncs(
      parent_sync: sync,
      window_start_date: sync.window_start_date,
      window_end_date: sync.window_end_date
    )
  end

  def perform_post_sync
    klutch_item.family.rules.each do |rule|
      rule.apply_later
    end
  end
end
