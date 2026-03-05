# frozen_string_literal: true

if Rails.respond_to?(:event)
  Rails.event.subscribe do |event|
    Rails.logger.info(
      event: event.name,
      payload: event.payload,
      tags: event.tags,
      context: event.context,
      source_location: event.source_location,
      timestamp_ns: event.timestamp
    )
  end
end
