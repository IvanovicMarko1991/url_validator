class AddContentVerificationFieldsToUrlValidationResults < ActiveRecord::Migration[8.1]
  def change
    add_column :url_validation_results, :page_title, :text
    add_column :url_validation_results, :title_match, :boolean
    add_column :url_validation_results, :content_error, :text
  end
end
