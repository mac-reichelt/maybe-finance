class CreateRecurringTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :recurring_transactions, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.references :category, type: :uuid, foreign_key: true
      t.references :merchant, type: :uuid, foreign_key: true

      t.string :title, null: false
      t.decimal :amount, precision: 19, scale: 4, null: false
      t.string :currency, null: false
      t.string :frequency, null: false
      t.integer :frequency_day
      t.integer :frequency_interval, default: 1
      t.date :start_date
      t.date :end_date
      t.date :next_expected_date
      t.boolean :is_subscription, default: false
      t.boolean :auto_detected, default: false
      t.float :confidence_score
      t.string :status, default: "active", null: false

      t.timestamps
    end

    add_index :recurring_transactions, :status
    add_index :recurring_transactions, :next_expected_date
    add_index :recurring_transactions, [:family_id, :title]
  end
end
