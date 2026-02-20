class CreateCsvImports < ActiveRecord::Migration[8.1]
  def change
    create_table :csv_imports do |t|
      t.string :source_file, null: false
      t.integer :status, null: false, default: 0
      t.integer :total_rows, null: false, default: 0
      t.integer :imported_rows, null: false, default: 0
      t.integer :failed_rows, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message

      t.timestamps
    end
  end
end
