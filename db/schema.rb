# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_21_160608) do
  create_table "companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "domain"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "csv_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "failed_rows", default: 0, null: false
    t.datetime "finished_at"
    t.integer "imported_rows", default: 0, null: false
    t.string "source_file", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "total_rows", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "jobs", force: :cascade do |t|
    t.integer "company_id", null: false
    t.datetime "created_at", null: false
    t.string "external_host"
    t.string "external_id"
    t.text "external_url", null: false
    t.text "last_error"
    t.integer "last_http_status"
    t.datetime "last_validated_at"
    t.integer "last_validation_status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "external_id"], name: "index_jobs_on_company_id_and_external_id", unique: true
    t.index ["company_id"], name: "index_jobs_on_company_id"
    t.index ["external_host"], name: "index_jobs_on_external_host"
    t.index ["last_validation_status"], name: "index_jobs_on_last_validation_status"
  end

  create_table "url_validation_results", force: :cascade do |t|
    t.integer "attempts_count", default: 0, null: false
    t.datetime "checked_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.text "final_url"
    t.datetime "finished_at"
    t.integer "http_status"
    t.integer "job_id", null: false
    t.datetime "last_retry_at"
    t.datetime "lease_expires_at"
    t.integer "processing_state", default: 0, null: false
    t.integer "response_time_ms"
    t.boolean "retry_eligible", default: true, null: false
    t.datetime "started_at"
    t.integer "status"
    t.integer "timeout_retry_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "url_validation_run_id", null: false
    t.string "worker_jid"
    t.index ["job_id"], name: "index_url_validation_results_on_job_id"
    t.index ["lease_expires_at"], name: "index_url_validation_results_on_lease_expires_at"
    t.index ["status"], name: "index_url_validation_results_on_status"
    t.index ["url_validation_run_id", "job_id"], name: "idx_uvr_run_job_unique", unique: true
    t.index ["url_validation_run_id", "processing_state"], name: "idx_uvr_run_processing"
    t.index ["url_validation_run_id", "status", "timeout_retry_count"], name: "idx_uvr_timeout_retry"
    t.index ["url_validation_run_id", "status"], name: "idx_on_url_validation_run_id_status_4f477673d2"
    t.index ["url_validation_run_id"], name: "index_url_validation_results_on_url_validation_run_id"
  end

  create_table "url_validation_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "csv_import_id"
    t.text "error_message"
    t.datetime "finished_at"
    t.integer "invalid_count", default: 0, null: false
    t.integer "processed_count", default: 0, null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "total_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "valid_count", default: 0, null: false
    t.index ["csv_import_id"], name: "index_url_validation_runs_on_csv_import_id"
  end

  add_foreign_key "jobs", "companies"
  add_foreign_key "url_validation_results", "jobs"
  add_foreign_key "url_validation_results", "url_validation_runs"
  add_foreign_key "url_validation_runs", "csv_imports"
end
