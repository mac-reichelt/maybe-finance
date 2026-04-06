require "test_helper"

class RecurringTransactionTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @recurring = recurring_transactions(:monthly_netflix)
  end

  test "valid recurring transaction" do
    assert @recurring.valid?
  end

  test "requires title" do
    @recurring.title = nil
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:title], "can't be blank"
  end

  test "requires amount" do
    @recurring.amount = nil
    assert_not @recurring.valid?
  end

  test "requires positive amount" do
    @recurring.amount = -10
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:amount], "must be greater than 0"
  end

  test "requires valid frequency" do
    @recurring.frequency = "invalid"
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:frequency], "is not included in the list"
  end

  test "requires valid status" do
    @recurring.status = "invalid"
    assert_not @recurring.valid?
  end

  test "validates confidence_score range" do
    @recurring.confidence_score = 1.5
    assert_not @recurring.valid?

    @recurring.confidence_score = -0.1
    assert_not @recurring.valid?

    @recurring.confidence_score = 0.85
    assert @recurring.valid?
  end

  test "subscription? returns true when is_subscription" do
    @recurring.is_subscription = true
    assert @recurring.subscription?

    @recurring.is_subscription = false
    assert_not @recurring.subscription?
  end

  test "active? returns true when status is active" do
    @recurring.status = "active"
    assert @recurring.active?

    @recurring.status = "paused"
    assert_not @recurring.active?
  end

  test "overdue? returns true when next_expected_date is in the past and active" do
    @recurring.next_expected_date = 1.day.ago
    @recurring.status = "active"
    assert @recurring.overdue?

    @recurring.next_expected_date = 1.day.from_now
    assert_not @recurring.overdue?
  end

  test "confirm! sets status to active" do
    pending = recurring_transactions(:pending_detected)
    assert_equal "pending_confirmation", pending.status

    pending.confirm!
    assert_equal "active", pending.reload.status
  end

  test "dismiss! sets status to cancelled" do
    pending = recurring_transactions(:pending_detected)
    pending.dismiss!
    assert_equal "cancelled", pending.reload.status
  end

  test "frequency_label returns human-readable label" do
    @recurring.frequency = "monthly"
    assert_equal "Monthly", @recurring.frequency_label

    @recurring.frequency = "weekly"
    @recurring.frequency_interval = 1
    assert_equal "Weekly", @recurring.frequency_label

    @recurring.frequency = "weekly"
    @recurring.frequency_interval = 2
    assert_equal "Every 2 weeks", @recurring.frequency_label

    @recurring.frequency = "annually"
    assert_equal "Annually", @recurring.frequency_label
  end

  test "calculates next_expected_date from start_date when blank" do
    rt = @family.recurring_transactions.create!(
      title: "Test",
      amount: 10.00,
      currency: "USD",
      frequency: "monthly",
      start_date: 2.months.ago.to_date
    )

    assert_not_nil rt.next_expected_date
    assert rt.next_expected_date >= Date.current
  end

  test "scopes work correctly" do
    assert RecurringTransaction.active.include?(@recurring)
    assert RecurringTransaction.subscriptions.include?(@recurring)
    assert RecurringTransaction.pending_confirmation.include?(recurring_transactions(:pending_detected))
    assert RecurringTransaction.auto_detected.include?(recurring_transactions(:pending_detected))
  end

  test "belongs to family" do
    assert_equal @family, @recurring.family
  end

  test "family has_many recurring_transactions" do
    assert_includes @family.recurring_transactions, @recurring
  end
end
