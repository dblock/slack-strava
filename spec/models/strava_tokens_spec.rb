require 'spec_helper'

describe StravaTokens do
  let(:user) { Fabricate(:user, access_token: 'old-access', refresh_token: 'old-refresh', token_type: 'Bearer', token_expires_at: 2.hours.from_now) }
  let(:response) { Hashie::Mash.new(access_token: 'new-access', refresh_token: 'new-refresh', token_type: 'Bearer', expires_at: 6.hours.from_now.to_i) }

  describe '#refresh_access_token!' do
    it 'does not refresh a token that remains valid for more than an hour' do
      expect(user.oauth_client).not_to receive(:oauth_token)
      user.refresh_access_token!
      expect(user.reload.access_token).to eq 'old-access'
    end

    it 'rotates and persists expiring credentials' do
      user.update_attributes!(token_expires_at: 30.minutes.from_now)
      allow(user.oauth_client).to receive(:oauth_token).with(refresh_token: 'old-refresh', grant_type: 'refresh_token').and_return(response)
      user.refresh_access_token!
      expect(user.reload.attributes.slice('access_token', 'refresh_token', 'token_type')).to eq(
        'access_token' => 'new-access', 'refresh_token' => 'new-refresh', 'token_type' => 'Bearer'
      )
      expect(user.token_expires_at.to_time.to_i).to eq response.expires_at
    end

    it 'supports legacy credentials without a refresh token or expiry' do
      user.update_attributes!(refresh_token: nil, token_expires_at: nil)
      allow(user.oauth_client).to receive(:oauth_token).with(refresh_token: 'old-access', grant_type: 'refresh_token').and_return(response)
      user.refresh_access_token!
      expect(user.reload.refresh_token).to eq 'new-refresh'
    end

    %i[access_token refresh_token].each do |missing|
      it "rejects a response missing #{missing} without replacing stored credentials" do
        user.update_attributes!(token_expires_at: 1.minute.ago)
        response[missing] = nil
        allow(user.oauth_client).to receive(:oauth_token).and_return(response)
        expect { user.refresh_access_token! }.to raise_error("Missing #{missing} in OAuth response.")
        expect(user.reload.access_token).to eq 'old-access'
        expect(user.refresh_token).to eq 'old-refresh'
      end
    end
  end

  describe '#get_access_token!' do
    it 'exchanges an authorization code with the correct grant' do
      allow(user.oauth_client).to receive(:oauth_token).with(code: 'authorization-code', grant_type: 'authorization_code').and_return(response)
      expect(user.get_access_token!('authorization-code')).to eq response
    end
  end

  describe '#reset_access_tokens!' do
    it 'clears persisted credentials together with the requested connection state' do
      user.update_attributes!(connected_to_strava_at: Time.now.utc)
      user.reset_access_tokens!(connected_to_strava_at: nil)
      expect(user.reload.attributes.slice('access_token', 'refresh_token', 'token_type', 'token_expires_at', 'connected_to_strava_at').values).to eq [nil] * 5
    end
  end

  describe '#revoke_access_token!' do
    it 'deauthorizes the connected athlete' do
      allow(user.strava_client).to receive(:deauthorize).with(access_token: 'old-access').and_return(Hashie::Mash.new(access_token: 'old-access'))
      expect { user.revoke_access_token! }.not_to raise_error
    end

    it 'skips disconnected users' do
      user.update_attributes!(access_token: nil)
      expect(user).not_to receive(:strava_client)
      user.revoke_access_token!
    end

    it 'rejects an unsuccessful deauthorization response' do
      allow(user.strava_client).to receive(:deauthorize).and_return(Hashie::Mash.new)
      expect { user.revoke_access_token! }.to raise_error('Missing access_token in deauthorize response.')
    end
  end
end
