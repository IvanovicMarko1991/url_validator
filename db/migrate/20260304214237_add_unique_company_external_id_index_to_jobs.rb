class AddUniqueCompanyExternalIdIndexToJobs < ActiveRecord::Migration[8.1]
  def change
    add_index :jobs, [ :company_id, :external_id ],
              unique: true,
              where: "external_id IS NOT NULL",
              name: "idx_jobs_company_external_id_unique"
  end
end
