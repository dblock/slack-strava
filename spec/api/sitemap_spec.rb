require 'spec_helper'

describe Api do
  include Api::Test::EndpointTest

  it 'returns a sitemap.xml with the indexable pages' do
    get '/sitemap.xml'
    expect(last_response.status).to eq 200
    expect(last_response.headers['Content-Type']).to eq 'application/xml; charset=utf-8'

    doc = Nokogiri::XML(last_response.body, &:strict)
    expect(doc.errors).to be_empty
    expect(last_response.body).to include '<loc>https://slava.playplay.io/</loc>'
    expect(last_response.body).to include '<loc>https://slava.playplay.io/help.html</loc>'
    expect(last_response.body).to include '<loc>https://slava.playplay.io/privacy.html</loc>'
  end
end
