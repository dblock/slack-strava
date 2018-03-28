class Athlete
  include Mongoid::Document
  include Mongoid::Timestamps

  field :athlete_id, type: String

  #   field :username, type: String
  #   field :firstname, type: String
  #   field :lastname, type: String
  #   field :city, type: String
  #   field :state, type: String
  #   field :country, type: String
  #   field :sex, type: String
  #   field :premium, type: Boolean
  #   field :athlete_created_at, type: DateTime
  #   field :athlete_updated_at, type: DateTime
  #   field :profile_medium, type: String
  #   field :profile, type: String
  #   field :email, type: String

  embedded_in :user
end
