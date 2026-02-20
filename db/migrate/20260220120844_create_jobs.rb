class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.references :company, null: false, foreign_key: true
      t.string :title, null: false
      t.text :external_url, null: false
      t.string :external_id
      t.integer :last_validation_status, null: false, default: 0
      t.integer :last_http_status
      t.text :last_error
      t.datetime :last_validated_at

      t.timestamps
    end

    add_index :jobs, [ :company_id, :external_id ], unique: true
    add_index :jobs, :last_validation_status
  end
end
