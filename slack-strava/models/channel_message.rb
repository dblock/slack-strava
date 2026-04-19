class ChannelMessage
  include Mongoid::Document

  field :ts, type: String
  field :channel, type: String
  field :details_ts, type: String
end
