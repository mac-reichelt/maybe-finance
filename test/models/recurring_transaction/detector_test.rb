require "test_helper"

class RecurringTransaction::DetectorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
  end

  test "detects monthly recurring transactions" do
    merchant = merchants(:netflix)

    # Create a pattern of monthly transactions
    5.times do |i|
      txn = Transaction.create!(category: categories(:food_and_drink), merchant: merchant)
      Entry.create!(
        account: @account,
        name: "Netflix",
        amount: 15.99,
        currency: "USD",
        date: (5 - i).months.ago.to_date + 15.days,
        entryable: txn
      )
    end

    detector = RecurringTransaction::Detector.new(@family)
    results = detector.detect

    netflix_result = results.find { |r| r.merchant_id == merchant.id }
    assert_not_nil netflix_result, "Should detect Netflix as recurring"
    assert_equal "monthly", netflix_result.frequency
    assert netflix_result.is_subscription
    assert netflix_result.confidence_score > 0.5
  end

  test "does not detect transactions with too few occurrences" do
    merchant = merchants(:amazon)

    # Only 2 transactions - below minimum threshold
    2.times do |i|
      txn = Transaction.create!(merchant: merchant)
      Entry.create!(
        account: @account,
        name: "Amazon",
        amount: 50.00,
        currency: "USD",
        date: (2 - i).months.ago.to_date,
        entryable: txn
      )
    end

    detector = RecurringTransaction::Detector.new(@family)
    results = detector.detect

    amazon_result = results.find { |r| r.merchant_id == merchant.id }
    assert_nil amazon_result, "Should not detect with only 2 occurrences"
  end

  test "detect_and_create! creates recurring transactions with pending status" do
    # Create a new merchant that has no existing recurring transaction
    merchant = FamilyMerchant.create!(name: "Spotify", family: @family)

    4.times do |i|
      txn = Transaction.create!(category: categories(:food_and_drink), merchant: merchant)
      Entry.create!(
        account: @account,
        name: "Spotify",
        amount: 9.99,
        currency: "USD",
        date: (4 - i).months.ago.to_date + 15.days,
        entryable: txn
      )
    end

    detector = RecurringTransaction::Detector.new(@family)

    assert_difference "RecurringTransaction.count" do
      created = detector.detect_and_create!
      assert created.all? { |rt| rt.status == "pending_confirmation" }
      assert created.all?(&:auto_detected)
    end
  end

  test "detect_and_create! does not duplicate existing recurring transactions" do
    # monthly_netflix fixture already exists
    merchant = merchants(:netflix)

    4.times do |i|
      txn = Transaction.create!(category: categories(:food_and_drink), merchant: merchant)
      Entry.create!(
        account: @account,
        name: "Netflix",
        amount: 15.99,
        currency: "USD",
        date: (4 - i).months.ago.to_date + 15.days,
        entryable: txn
      )
    end

    detector = RecurringTransaction::Detector.new(@family)
    created = detector.detect_and_create!

    netflix_created = created.select { |rt| rt.merchant_id == merchant.id }
    assert_empty netflix_created, "Should not duplicate existing Netflix recurring transaction"
  end
end
