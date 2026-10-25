require 'spec_helper'

describe Api::Middleware do
  include Rack::Test::Methods

  let(:app) { described_class.instance }
  let(:artwork) { 'public/img/screenshot-background.svg' }

  %w[/ /help.html /privacy.html /connect.html /subscribe.html /update_cc.html].each do |path|
    it "serves #{path} with content-versioned assets and private revalidation" do
      get path

      expect(last_response.status).to eq 200
      expect(last_response.headers['Cache-Control']).to eq 'private, no-cache'
      document = Capybara.string(last_response.body)
      assets = document.all('script[src^="/"], link[rel="icon"], link[rel="stylesheet"][href^="/"], img[src^="/"], meta[property="og:image"], script[data-image]', visible: :all)
      expect(assets).not_to be_empty
      assets.each do |asset|
        uri = URI.parse(asset[:'data-image'] || asset[:src] || asset[:href] || asset[:content])
        file = "public#{uri.path}"
        file += '.erb' unless File.file?(file)
        expect(uri.query).to eq "v=#{Digest::SHA256.file(file).hexdigest}"
      end
    end
  end

  it 'versions the JavaScript checkout image without HTML escaping' do
    get '/subscribe.html'

    image = "/img/icon.png?v=#{Digest::SHA256.file('public/img/icon.png').hexdigest}"
    expect(last_response.body).to include("image: #{image.to_json}")
  end

  it 'renders a revalidating stylesheet with content-versioned artwork' do
    get '/styles.css'

    expect(last_response.content_type).to eq 'text/css; charset=utf-8'
    expect(last_response.headers['Cache-Control']).to eq 'private, no-cache'
    expect(last_response.body).to include("/img/screenshot-background.svg?v=#{Digest::SHA256.file(artwork).hexdigest}")
  end

  it 'does not validate generated CSS using only its unchanged source timestamp' do
    get '/styles.css', {}, 'HTTP_IF_MODIFIED_SINCE' => File.mtime('public/styles.css.erb').httpdate

    expect(last_response.status).to eq 200
    expect(last_response.headers['Last-Modified']).to be_nil
  end

  it 'refreshes nested artwork even when the stylesheet source hash has not changed' do
    get '/styles.css'
    etag = last_response.headers['ETag']
    changed_digest = Digest::SHA256.hexdigest('updated ribbon artwork')
    allow(Digest::SHA256).to receive(:file).and_call_original
    allow(Digest::SHA256).to receive(:file).with(artwork).and_return(instance_double(Digest::SHA256, hexdigest: changed_digest))

    get '/styles.css', {}, 'HTTP_IF_NONE_MATCH' => etag,
                           'HTTP_IF_MODIFIED_SINCE' => File.mtime('public/styles.css.erb').httpdate

    expect(last_response.status).to eq 200
    expect(last_response.body).to include("/img/screenshot-background.svg?v=#{changed_digest}")
    expect(last_response.headers['ETag']).not_to eq etag
  end

  it 'revalidates static assets with their content ETag' do
    get '/scripts/strava.js'
    etag = last_response.headers['ETag']
    expect(etag).to eq %("#{Digest::SHA256.file('public/scripts/strava.js').hexdigest}")

    get '/scripts/strava.js', {}, 'HTTP_IF_NONE_MATCH' => etag

    expect(last_response.status).to eq 304
    expect(last_response.body).to be_empty
  end

  it 'returns current content for an old version URL and ETag despite a matching timestamp' do
    get '/scripts/strava.js?v=old-content', {}, 'HTTP_IF_NONE_MATCH' => '"old-content"',
                                                'HTTP_IF_MODIFIED_SINCE' => File.mtime('public/scripts/strava.js').httpdate

    expect(last_response.status).to eq 200
    expect(last_response.body).to eq File.read('public/scripts/strava.js')
  end
end
