class RecurringTransaction::Detector
  MIN_OCCURRENCES = 3
  AMOUNT_TOLERANCE = 0.15 # 15% tolerance for amount variation
  DATE_TOLERANCE_DAYS = 3 # Days tolerance for pattern matching

  Result = Struct.new(:title, :amount, :currency, :frequency, :frequency_day,
                      :start_date, :next_expected_date, :is_subscription,
                      :confidence_score, :merchant_id, :category_id, keyword_init: true)

  def initialize(family)
    @family = family
  end

  def detect
    candidates = find_recurring_candidates
    candidates.map { |candidate| build_result(candidate) }.compact
  end

  def detect_and_create!
    results = detect
    created = []

    results.each do |result|
      existing = @family.recurring_transactions.find_by(
        title: result.title,
        merchant_id: result.merchant_id
      )
      next if existing

      recurring = @family.recurring_transactions.create!(
        title: result.title,
        amount: result.amount,
        currency: result.currency,
        frequency: result.frequency,
        frequency_day: result.frequency_day,
        start_date: result.start_date,
        next_expected_date: result.next_expected_date,
        is_subscription: result.is_subscription,
        confidence_score: result.confidence_score,
        merchant_id: result.merchant_id,
        category_id: result.category_id,
        auto_detected: true,
        status: "pending_confirmation"
      )

      created << recurring
    end

    created
  end

  private

    def find_recurring_candidates
      groups = group_transactions
      groups.filter_map { |key, transactions| analyze_group(key, transactions) }
    end

    def group_transactions
      # Group transactions by merchant + similar name patterns
      transactions = @family.transactions
        .joins(:entry)
        .where(entries: { date: 1.year.ago..Date.current })
        .includes(:entry, :merchant, :category)
        .order("entries.date ASC")

      groups = {}

      transactions.each do |txn|
        key = grouping_key(txn)
        next if key.blank?

        groups[key] ||= []
        groups[key] << txn
      end

      groups
    end

    def grouping_key(transaction)
      if transaction.merchant_id.present?
        "merchant:#{transaction.merchant_id}"
      else
        name = transaction.entry.name.downcase.strip
        # Normalize common patterns (remove dates, numbers at end)
        normalized = name.gsub(/\s*#?\d+\s*$/, "").gsub(/\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s*\d*\s*$/i, "").strip
        "name:#{normalized}" if normalized.present?
      end
    end

    def analyze_group(key, transactions)
      return nil if transactions.size < MIN_OCCURRENCES

      # Check for consistent amounts
      amounts = transactions.map { |t| t.entry.amount.abs.to_f }
      avg_amount = amounts.sum / amounts.size

      # Filter to transactions with similar amounts
      consistent = transactions.select do |t|
        amt = t.entry.amount.abs.to_f
        (amt - avg_amount).abs / avg_amount <= AMOUNT_TOLERANCE
      end

      return nil if consistent.size < MIN_OCCURRENCES

      # Detect frequency pattern
      dates = consistent.map { |t| t.entry.date }.sort
      frequency_info = detect_frequency(dates)
      return nil unless frequency_info

      {
        key: key,
        transactions: consistent,
        amounts: consistent.map { |t| t.entry.amount.abs.to_f },
        dates: dates,
        frequency: frequency_info[:frequency],
        frequency_day: frequency_info[:frequency_day],
        confidence: frequency_info[:confidence]
      }
    end

    def detect_frequency(dates)
      return nil if dates.size < MIN_OCCURRENCES

      intervals = dates.each_cons(2).map { |a, b| (b - a).to_i }
      avg_interval = intervals.sum.to_f / intervals.size

      # Check for monthly pattern (28-31 days)
      if avg_interval.between?(25, 35)
        day_of_month = dates.map(&:day)
        most_common_day = day_of_month.tally.max_by { |_, v| v }&.first
        consistency = day_of_month.count { |d| (d - most_common_day).abs <= DATE_TOLERANCE_DAYS }.to_f / day_of_month.size

        return { frequency: "monthly", frequency_day: most_common_day, confidence: consistency } if consistency >= 0.6
      end

      # Check for weekly pattern (6-8 days)
      if avg_interval.between?(5, 9)
        consistency = intervals.count { |i| i.between?(5, 9) }.to_f / intervals.size
        return { frequency: "weekly", frequency_day: dates.last.wday, confidence: consistency } if consistency >= 0.6
      end

      # Check for bi-weekly pattern (12-16 days)
      if avg_interval.between?(12, 16)
        consistency = intervals.count { |i| i.between?(12, 16) }.to_f / intervals.size
        return { frequency: "semi_monthly", frequency_day: dates.last.day, confidence: consistency } if consistency >= 0.6
      end

      # Check for quarterly pattern (85-95 days)
      if avg_interval.between?(80, 100)
        consistency = intervals.count { |i| i.between?(80, 100) }.to_f / intervals.size
        return { frequency: "quarterly", frequency_day: dates.last.day, confidence: consistency } if consistency >= 0.6
      end

      # Check for annual pattern (350-380 days)
      if avg_interval.between?(350, 380)
        consistency = intervals.count { |i| i.between?(350, 380) }.to_f / intervals.size
        return { frequency: "annually", frequency_day: dates.last.day, confidence: consistency } if consistency >= 0.6
      end

      # Check for daily pattern
      if avg_interval.between?(0.8, 1.5)
        consistency = intervals.count { |i| i == 1 }.to_f / intervals.size
        return { frequency: "daily", frequency_day: nil, confidence: consistency } if consistency >= 0.6
      end

      nil
    end

    def build_result(candidate)
      transactions = candidate[:transactions]
      latest = transactions.max_by { |t| t.entry.date }
      amounts = candidate[:amounts]
      avg_amount = amounts.sum / amounts.size

      # Determine if it's likely a subscription (consistent amount, monthly or annual)
      amount_variance = amounts.map { |a| (a - avg_amount).abs }.max / avg_amount
      is_subscription = amount_variance < 0.05 && %w[monthly annually quarterly].include?(candidate[:frequency])

      # Calculate next expected date
      last_date = candidate[:dates].last
      next_date = project_next_date(last_date, candidate[:frequency], candidate[:frequency_day])

      Result.new(
        title: transaction_title(latest),
        amount: avg_amount.round(2),
        currency: latest.entry.currency,
        frequency: candidate[:frequency],
        frequency_day: candidate[:frequency_day],
        start_date: candidate[:dates].first,
        next_expected_date: next_date,
        is_subscription: is_subscription,
        confidence_score: candidate[:confidence].round(2),
        merchant_id: latest.merchant_id,
        category_id: latest.category_id
      )
    end

    def transaction_title(transaction)
      if transaction.merchant.present?
        transaction.merchant.name
      else
        transaction.entry.name
      end
    end

    def project_next_date(last_date, frequency, frequency_day)
      today = Date.current
      next_date = case frequency
      when "daily"
        last_date + 1.day
      when "weekly"
        last_date + 1.week
      when "monthly"
        last_date >> 1
      when "semi_monthly"
        last_date + 15.days
      when "quarterly"
        last_date >> 3
      when "annually"
        last_date >> 12
      else
        last_date + 1.month
      end

      # If projected date is in the past, advance to future
      while next_date < today
        next_date = case frequency
        when "daily" then next_date + 1.day
        when "weekly" then next_date + 1.week
        when "monthly" then next_date >> 1
        when "semi_monthly" then next_date + 15.days
        when "quarterly" then next_date >> 3
        when "annually" then next_date >> 12
        else next_date + 1.month
        end
      end

      next_date
    end
end
