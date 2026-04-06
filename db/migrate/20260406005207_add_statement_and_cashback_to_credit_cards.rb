class AddStatementAndCashbackToCreditCards < ActiveRecord::Migration[7.2]
  def change
    add_column :credit_cards, :statement_end_day, :integer
    add_column :credit_cards, :payment_due_day, :integer
    add_column :credit_cards, :cashback_percentage, :decimal, precision: 10, scale: 2
  end
end
