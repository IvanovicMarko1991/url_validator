# frozen_string_literal: true

require "json"
require "time"

class JsonLogFormatter < Logger::Formatter
  def call(severity, time, progname, msg)
    payload =
      case msg
      when Hash
        msg
      else
        { message: msg.to_s }
      end

    payload = payload.merge(
      level: severity,
      timestamp: time.utc.iso8601(6),
      progname: progname
    )

    "#{payload.to_json}\n"
  end
end
