class ChannelMessage
  include Mongoid::Document

  field :ts, type: String
  field :channel, type: String
end
