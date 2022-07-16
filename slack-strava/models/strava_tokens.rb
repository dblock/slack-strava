module StravaTokens
  extend ActiveSupport::Concern

  included do
    field :access_token, type: String
    field :token_type, type: String
    field :refresh_token, type: String
    field :token_expires_at, type: DateTime
  end

  def oauth_client
    @oauth_client ||= Strava::OAuth::Client.new(
      client_id: ENV.fetch('STRAVA_CLIENT_ID', nil),
      client_secret: ENV.fetch('STRAVA_CLIENT_SECRET', nil)
    )
  end

  def get_access_token!(code)
    oauth_client.oauth_token(code: code, grant_type: 'authorization_code')
  end

  def reset_access_tokens!(attrs = {})
    update_attributes!(
      attrs.merge(
        token_type: nil,
        access_token: nil,
        refresh_token: nil,
        token_expires_at: nil
      )
    )
  end

  def refresh_access_token!
    return if token_expires_at && Time.now + 1.hour < token_expires_at

    response = oauth_client.oauth_token(
      refresh_token: refresh_token || access_token, # TODO: remove access_token after migration
      grant_type: 'refresh_token'
    )

    raise 'Missing access_token in OAuth response.' unless response.access_token
    unless response.refresh_token
      raise 'Missing refresh_token in OAuth response.'
    end

    update_attributes!(
      token_type: response.token_type,
      access_token: response.access_token,
      refresh_token: response.refresh_token,
      token_expires_at: Time.at(response.expires_at)
    )
  end

  def strava_client
    @strava_client ||= begin
      refresh_access_token!
      raise 'Missing access_token' unless access_token

      Strava::Api::Client.new(access_token: access_token)
    end
  end
end
