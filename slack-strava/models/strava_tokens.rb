module StravaTokens
  extend ActiveSupport::Concern

  included do
    field :access_token, type: String
    field :token_type, type: String
    field :refresh_token, type: String
    field :token_expires_at, type: DateTime
  end

  def get_access_token!(code)
    args = {
      client_id: ENV['STRAVA_CLIENT_ID'],
      client_secret: ENV['STRAVA_CLIENT_SECRET'],
      grant_type: 'authorization_code',
      code: code
    }

    response = HTTMultiParty.public_send(
      'post',
      Strava::Api::V3::Configuration::DEFAULT_AUTH_ENDPOINT,
      query: args
    )

    raise Strava::Api::V3::ServerError.new(response.code.to_i, response.body) unless response.success?

    response
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

    args = {
      client_id: ENV['STRAVA_CLIENT_ID'],
      client_secret: ENV['STRAVA_CLIENT_SECRET'],
      grant_type: 'refresh_token',
      refresh_token: refresh_token || access_token # TODO: remove access_token after migration
    }

    response = HTTMultiParty.post(
      Strava::Api::V3::Configuration::DEFAULT_AUTH_ENDPOINT,
      query: args
    )

    raise Strava::Api::V3::ServerError.new(response.code.to_i, response.body) unless response.success?

    update_attributes!(
      token_type: response['token_type'],
      access_token: response['access_token'],
      refresh_token: response['refresh_token'],
      token_expires_at: Time.at(response['expires_at'])
    )
  end

  def strava_client
    @strava_client ||= begin
      refresh_access_token!
      raise 'Missing access_token' unless access_token
      Strava::Api::V3::Client.new(access_token: access_token)
    end
  end
end
