require "test_helper"

class RecurringTransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @recurring_transaction = recurring_transactions(:monthly_netflix)
  end

  test "index" do
    get recurring_transactions_url
    assert_response :success
  end

  test "new" do
    get new_recurring_transaction_url
    assert_response :success
  end

  test "create" do
    assert_difference "RecurringTransaction.count", 1 do
      post recurring_transactions_url, params: {
        recurring_transaction: {
          title: "Spotify",
          amount: 9.99,
          currency: "USD",
          frequency: "monthly",
          start_date: Date.current,
          is_subscription: true
        }
      }
    end

    assert_redirected_to recurring_transactions_url
  end

  test "create with invalid params" do
    assert_no_difference "RecurringTransaction.count" do
      post recurring_transactions_url, params: {
        recurring_transaction: {
          title: "",
          amount: -1,
          currency: "USD",
          frequency: "invalid"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "show" do
    get recurring_transaction_url(@recurring_transaction)
    assert_response :success
  end

  test "edit" do
    get edit_recurring_transaction_url(@recurring_transaction)
    assert_response :success
  end

  test "update" do
    patch recurring_transaction_url(@recurring_transaction), params: {
      recurring_transaction: {
        title: "Updated Netflix",
        amount: 19.99
      }
    }

    assert_redirected_to recurring_transactions_url
    assert_equal "Updated Netflix", @recurring_transaction.reload.title
    assert_equal 19.99, @recurring_transaction.reload.amount.to_f
  end

  test "destroy" do
    assert_difference "RecurringTransaction.count", -1 do
      delete recurring_transaction_url(@recurring_transaction)
    end

    assert_redirected_to recurring_transactions_url
  end

  test "confirm" do
    pending = recurring_transactions(:pending_detected)
    post confirm_recurring_transaction_url(pending)
    assert_redirected_to recurring_transactions_url
    assert_equal "active", pending.reload.status
  end

  test "dismiss" do
    pending = recurring_transactions(:pending_detected)
    post dismiss_recurring_transaction_url(pending)
    assert_redirected_to recurring_transactions_url
    assert_equal "cancelled", pending.reload.status
  end

  test "detect" do
    post detect_recurring_transactions_url
    assert_redirected_to recurring_transactions_url
  end
end
