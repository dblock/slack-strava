require 'spec_helper'

describe Api do
  include Api::Test::EndpointTest

  context 'swagger root' do
    subject do
      get '/api/swagger_doc'
      JSON.parse(last_response.body)
    end
    it 'documents root level apis' do
      expect(subject['paths'].keys).to eq ['/api/status', '/api/teams', '/api/teams/{id}', '/api/subscriptions', '/api/credit_cards']
    end
  end

  context 'teams' do
    subject do
      get '/api/swagger_doc/teams'
      JSON.parse(last_response.body)
    end
    it 'documents teams apis' do
      expect(subject['paths'].keys).to eq ['/api/teams', '/api/teams/{id}']
    end
  end
end
