namespace :data do
  desc "Backfill jobs.normalized_external_url and jobs.external_host"
  task backfill_normalized_urls: :environment do
    count = 0

    Job.find_each(batch_size: 500) do |job|
      normalized = UrlValidation::UrlNormalizer.normalize(job.external_url)
      host = UrlValidation::UrlNormalizer.host(normalized)

      next if job.normalized_external_url == normalized && job.external_host == host

      job.update_columns(
        normalized_external_url: normalized,
        external_host: host,
        updated_at: Time.current
      )
      count += 1
    end

    puts "Updated #{count} jobs"
  end
end
