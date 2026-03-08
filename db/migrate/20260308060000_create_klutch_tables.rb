class CreateKlutchTables < ActiveRecord::Migration[7.2]
  def change
    create_table :klutch_items, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :endpoint, null: false
      t.string :client_id, null: false
      t.string :secret_key, null: false
      t.string :name, null: false
      t.string :status, null: false, default: "good"
      t.boolean :scheduled_for_deletion, default: false
      t.jsonb :raw_payload, default: {}

      t.timestamps
    end

    create_table :klutch_accounts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :klutch_item, null: false, foreign_key: true, type: :uuid
      t.string :klutch_id, null: false
      t.string :name, null: false
      t.string :currency, null: false, default: "USD"
      t.decimal :current_balance, precision: 19, scale: 4
      t.jsonb :raw_payload, default: {}
      t.jsonb :raw_transactions_payload, default: {}

      t.timestamps

      t.index :klutch_id, unique: true
    end

    add_reference :accounts, :klutch_account, type: :uuid, foreign_key: true, index: true

    add_column :entries, :klutch_id, :string
    add_index :entries, :klutch_id
  end
end
