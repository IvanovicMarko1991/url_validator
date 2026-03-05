class AddNormalizedExternalUrlToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :normalized_external_url, :text

    add_index :jobs, [ :company_id, :normalized_external_url ],
              unique: true,
              where: "external_id IS NULL AND normalized_external_url IS NOT NULL",
              name: "idx_jobs_company_normalized_url_when_no_external_id"
  end
end
