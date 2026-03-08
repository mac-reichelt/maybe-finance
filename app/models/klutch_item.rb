class KlutchItem < ApplicationRecord
  include Syncable

  enum :status, { good: "good", requires_update: "requires_update" }, default: :good

  if Rails.application.credentials.active_record_encryption.present?
    encrypts :client_id, deterministic: true
    encrypts :secret_key, deterministic: true
  end

  validates :name, :endpoint, :client_id, :secret_key, presence: true

  belongs_to :family
  has_one_attached :logo

  has_many :klutch_accounts, dependent: :destroy
  has_many :accounts, through: :klutch_accounts

  scope :active, -> { where(scheduled_for_deletion: false) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :needs_update, -> { where(status: :requires_update) }

  def destroy_later
    update!(scheduled_for_deletion: true)
    DestroyJob.perform_later(self)
  end

  def klutch_provider
    @klutch_provider ||= Provider::Klutch.new(
      endpoint: endpoint,
      client_id: client_id,
      secret_key: secret_key
    )
  end

  def import_latest_klutch_data
    KlutchItem::Importer.new(self, klutch_provider: klutch_provider).import
  end

  def process_accounts
    klutch_accounts.each do |klutch_account|
      KlutchAccount::Processor.new(klutch_account).process
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
