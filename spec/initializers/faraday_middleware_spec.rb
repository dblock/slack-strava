require 'spec_helper'

describe Faraday::Middleware do
  context Faraday::Response::RaiseError do
    it 'default_options' do
      expect(Faraday::Response::RaiseError.default_options).to eq(include_request: true, allowed_statuses: [])
    end
  end

  context Strava::Web::RaiseResponseError do
    it 'default_options' do
      expect(Faraday::Response::RaiseError.default_options).to eq(include_request: true, allowed_statuses: [])
    end
  end
end
