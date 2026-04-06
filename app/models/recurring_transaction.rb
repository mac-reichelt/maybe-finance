class RecurringTransaction < ApplicationRecord
  belongs_to :family
  belongs_to :category, optional: true
  belongs_to :merchant, optional: true

  FREQUENCIES = %w[daily weekly monthly semi_monthly quarterly annually custom].freeze
  STATUSES = %w[active paused cancelled pending_confirmation].freeze

  validates :title, :amount, :currency, :frequency, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :status, inclusion: { in: STATUSES }
  validates :amount, numericality: { greater_than: 0 }
  validates :frequency_interval, numericality: { greater_than: 0 }, allow_nil: true
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

  scope :active, -> { where(status: "active") }
  scope :subscriptions, -> { where(is_subscription: true) }
  scope :pending_confirmation, -> { where(status: "pending_confirmation") }
  scope :auto_detected, -> { where(auto_detected: true) }
  scope :upcoming, -> { where("next_expected_date >= ?", Date.current).order(:next_expected_date) }
  scope :alphabetically, -> { order(:title) }

  before_save :calculate_next_expected_date, if: -> { next_expected_date.blank? && start_date.present? }

  def subscription?
    is_subscription
  end

  def confirmed?
    status != "pending_confirmation"
  end

  def active?
    status == "active"
  end

  def overdue?
    next_expected_date.present? && next_expected_date < Date.current && active?
  end

  def confirm!
    update!(status: "active")
  end

  def dismiss!
    update!(status: "cancelled")
  end

  def pause!
    update!(status: "paused")
  end

  def resume!
    update!(status: "active")
  end

  def frequency_label
    case frequency
    when "daily" then "Daily"
    when "weekly"
      frequency_interval == 1 ? "Weekly" : "Every #{frequency_interval} weeks"
    when "monthly" then "Monthly"
    when "semi_monthly" then "Semi-monthly"
    when "quarterly" then "Quarterly"
    when "annually" then "Annually"
    when "custom" then "Custom"
    else frequency.humanize
    end
  end

  def calculate_next_expected_date
    return unless start_date.present?

    base_date = start_date
    today = Date.current

    # Find the next occurrence after today
    interval = frequency_interval.presence || 1

    self.next_expected_date = case frequency
    when "daily"
      days = ((today - base_date).to_i / interval) + 1
      base_date + (days * interval).days
    when "weekly"
      weeks = ((today - base_date).to_i / (7 * interval)) + 1
      base_date + (weeks * interval).weeks
    when "monthly"
      next_monthly_date(base_date, today)
    when "semi_monthly"
      next_semi_monthly_date(base_date, today)
    when "quarterly"
      next_monthly_date(base_date, today, 3)
    when "annually"
      next_date = base_date
      next_date = next_date.next_year while next_date <= today
      next_date
    else
      today + 1.month
    end
  end

  private

    def next_monthly_date(base_date, today, month_interval = 1)
      next_date = base_date
      while next_date <= today
        next_date = next_date >> month_interval
      end
      next_date
    end

    def next_semi_monthly_date(base_date, today)
      day = base_date.day
      # Semi-monthly: on the day and 15 days later (or 1st and 15th)
      first_day = [ day, 15 ].min
      second_day = [ day, 15 ].max

      candidates = [
        Date.new(today.year, today.month, [ first_day, Time.days_in_month(today.month, today.year) ].min),
        Date.new(today.year, today.month, [ second_day, Time.days_in_month(today.month, today.year) ].min)
      ]

      # Find next occurrence after today
      future = candidates.select { |d| d > today }
      return future.min if future.any?

      # Move to next month
      next_month = today.next_month
      Date.new(next_month.year, next_month.month, [ first_day, Time.days_in_month(next_month.month, next_month.year) ].min)
    end
end
