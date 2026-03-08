class SimplefinItem < ApplicationRecord
  include Syncable

  enum :status, { good: "good", requires_update: "requires_update" }, default: :good

  if Rails.application.credentials.active_record_encryption.present?
    encrypts :access_url, deterministic: true
  end

  validates :name, :access_url, presence: true

  belongs_to :family
  has_one_attached :logo

  has_many :simplefin_accounts, dependent: :destroy
  has_many :accounts, through: :simplefin_accounts

  scope :active, -> { where(scheduled_for_deletion: false) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :needs_update, -> { where(status: :requires_update) }

  def destroy_later
    update!(scheduled_for_deletion: true)
    DestroyJob.perform_later(self)
  end

  def simplefin_provider
    @simplefin_provider ||= Provider::Simplefin.new(access_url)
  end

  def import_latest_simplefin_data
    SimplefinItem::Importer.new(self, simplefin_provider: simplefin_provider).import
  end

  def process_accounts
    simplefin_accounts.each do |simplefin_account|
      SimplefinAccount::Processor.new(simplefin_account).process
    end
  end

  def schedule_account_syncs(parent_sync: nil, window_start_date: nil, window_end_date: nil)
    accounts.each do |account|
      account.sync_later(
        parent_sync: parent_sync,
        window_start_date: window_start_date,
        window_end_date: window_end_date
      )
    end
  end
end
