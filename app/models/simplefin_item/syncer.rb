class SimplefinItem::Syncer
  attr_reader :simplefin_item

  def initialize(simplefin_item)
    @simplefin_item = simplefin_item
  end

  def perform_sync(sync)
    simplefin_item.import_latest_simplefin_data

    simplefin_item.process_accounts

    simplefin_item.schedule_account_syncs(
      parent_sync: sync,
      window_start_date: sync.window_start_date,
      window_end_date: sync.window_end_date
    )
  end

  def perform_post_sync
    simplefin_item.family.rules.each do |rule|
      rule.apply_later
    end
  end
end
