class Athlete
  include Mongoid::Document
  include Mongoid::Timestamps

  field :athlete_id, type: String
  field :username, type: String
  field :firstname, type: String
  field :lastname, type: String
  #   field :city, type: String
  #   field :state, type: String
  #   field :country, type: String
  #   field :sex, type: String
  #   field :premium, type: Boolean
  #   field :athlete_created_at, type: DateTime
  #   field :athlete_updated_at, type: DateTime
  field :profile_medium, type: String
  field :profile, type: String
  #   field :email, type: String

  embedded_in :user

  def name
    [firstname, lastname].compact.join(' ') if firstname || lastname
  end

  def strava_url
    "https://www.strava.com/athletes/#{username || athlete_id}"
  end

  def self.attrs_from_strava(response)
    {
      athlete_id: response['id'],
      username: response['username'],
      firstname: response['firstname'],
      lastname: response['lastname'],
      profile: response['profile'],
      profile_medium: response['profile_medium']
    }
  end

  def to_slack
    {
      author_name: name,
      author_link: strava_url,
      author_icon: profile_medium
    }
  end

  def sync!
    raise 'Missing access_token' unless user.access_token
    client = Strava::Api::V3::Client.new(access_token: user.access_token)
    info = client.retrieve_current_athlete
    update_attributes!(Athlete.attrs_from_strava(info))
    self
  end
end
