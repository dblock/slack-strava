require 'spec_helper'
require 'nokogiri'

describe Api do
  include Api::Test::EndpointTest

  it 'shares navigation, content layout, and footer across every website page' do
    %w[/ /help.html /privacy.html /connect.html /subscribe.html /update_cc.html].each do |path|
      get path

      expect(last_response.status).to eq 200
      document = Nokogiri::HTML(last_response.body)
      expect(document.at_css('body.site-page > nav[aria-label="Main navigation"]')).not_to be_nil
      expect(document.at_css('main#main')).not_to be_nil
      expect(document.at_css('body > footer.site-footer')).not_to be_nil
    end
  end

  it 'retains Slack onboarding, threading, and activity-link guidance' do
    get '/help.html'

    document = Nokogiri::HTML(last_response.body)
    expect(document.at_css('#get-started').text).to include('@slava', '/slava connect')
    expect(document.at_css('#commands').text).to include('set threads daily', 'set leaderboard', 'unfurl')
    expect(document.at_css('#support a')['href']).to eq 'mailto:dblock@vestris.com'
  end
end
