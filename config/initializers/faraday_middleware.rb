Faraday::Response::RaiseError.default_options = { include_request: true, allowed_statuses: [] }

module Strava
  module Web
    class RaiseResponseError
      DEFAULT_OPTIONS = { include_request: true, allowed_statuses: [] }.freeze
    end
  end
end
