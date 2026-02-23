# URL Validator (Rails + Sidekiq)

A Ruby on Rails service that imports jobs from a CSV file and validates each job’s external URL in the background.

It stores:
- companies
- jobs
- validation runs
- per-job validation results

The goal is to generate a report showing how many job URLs are valid/invalid and why.

---

## Current Status

✅ Backend/API implemented  
✅ CSV import  
✅ Background URL validation with Sidekiq  
✅ Scalable fan-out processing (one worker per URL validation row)  
✅ Run progress tracking and reporting  

🚧 No web UI yet (API + Postman flow for now)

---

## Features

- Import jobs from CSV (`company_name`, `title`, `external_url`, `external_id`)
- Create/update `Company` and `Job` records
- Start a `UrlValidationRun`
- Fan-out background validation jobs with Sidekiq
- Store per-job validation results (`valid`, `invalid_http`, `redirected`, `timed_out`, etc.)
- Track progress (`total_count`, `processed_count`, `valid_count`, `invalid_count`)
- Recover from worker crashes using lease-based processing
- Finalizer worker to ensure consistency and finalize runs

---

## Tech Stack

- Ruby 3.4
- Rails 8.1.2
- PostgreSQL (recommended)
- Sidekiq
- Redis

---

## Architecture (Current)

### Flow
1. Upload CSV via API
2. Importer creates/updates `Company` + `Job`
3. Create `UrlValidationRun`
4. Pre-create `UrlValidationResult` rows in `pending`
5. Enqueue Sidekiq jobs (fan-out, one per validation row)
6. Workers validate URLs and write results
7. Finalizer worker requeues stuck rows and finalizes the run

### Why fan-out?
This design scales better for large CSVs (thousands of jobs):
- parallel processing
- better retry behavior
- better observability
- safer consistency

---

## Data Model (Entities)

### `Company`
- `name`
- `domain` (optional)

### `Job`
- `company_id`
- `title`
- `external_url`
- `external_id` (optional)
- validation snapshot fields:
  - `last_validation_status`
  - `last_http_status`
  - `last_error`
  - `last_validated_at`

### `CsvImport`
Tracks a CSV upload/import.
- `source_file`
- `status`
- `total_rows`
- `imported_rows`
- `failed_rows`

### `UrlValidationRun`
Tracks one validation run/report.
- `status`
- `total_count`
- `processed_count`
- `valid_count`
- `invalid_count`

### `UrlValidationResult`
One row per job validation attempt/result in a run.
- `url_validation_run_id`
- `job_id`
- `processing_state` (`pending`, `running`, `completed`)
- `status` (`valid`, `invalid_http`, `redirected`, `malformed_url`, `timed_out`, etc.)
- `http_status`
- `error_message`
- `attempts_count`
- lease fields for crash recovery

---

## Local Setup

### 1) Install dependencies
```bash
bundle install
```

## CSV Example
```bash
company_name,title,external_url,external_id
Acme,Backend Engineer,https://acme.com/jobs/123,acme-123
Acme,Frontend Engineer,https://acme.com/jobs/456,acme-456
Globex,QA Engineer,https://globex.com/careers/qa-1,globex-qa-1
```
