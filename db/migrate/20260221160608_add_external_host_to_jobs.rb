class AddExternalHostToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :external_host, :string
    add_index :jobs, :external_host
  end
end
