class Photo
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :user_activity

  field :unique_id, type: String
  field :urls, type: Hash
  field :source, type: Integer
  field :caption, type: String
  field :photo_created_at, type: DateTime
  field :photo_created_at_local, type: DateTime
  field :uploaded_at, type: DateTime
  field :sizes, type: Hash
  field :default_photo, type: Boolean

  def to_s
    "unique_id=#{unique_id}, default=#{default_photo}"
  end

  def to_slack
    {
      type: 'image',
      image_url: urls.values.first,
      alt_text: caption.to_s
    }
  end

  def self.detailed_attrs_from_strava(response)
    {
      unique_id: response.unique_id,
      urls: response.urls,
      source: response.source,
      caption: response.caption,
      photo_created_at: response.created_at,
      photo_created_at_local: response.created_at_local,
      uploaded_at: response.uploaded_at,
      sizes: response.sizes,
      default_photo: response.default_photo
    }
  end

  def self.summary_attrs_from_strava(response)
    {
      unique_id: response.unique_id,
      urls: response.urls,
      source: response.source
    }
  end

  alias eql? ==

  def ==(other)
    other.is_a?(Photo) &&
      unique_id == other.unique_id
  end
end
