class Map
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :user_activity

  field :strava_id, type: String
  field :summary_polyline, type: String
  field :decoded_summary_polyline, type: Array
  field :png, type: BSON::Binary
  field :png_retrieved_at, type: DateTime

  before_save :update_decoded_summary_polyline
  before_save :update_png

  def self.attrs_from_strava(response)
    {
      strava_id: response.id,
      summary_polyline: response.summary_polyline
    }
  end

  def update!
    update_decoded_summary_polyline!
    update_png!
  end

  def start_latlng
    return unless decoded_summary_polyline&.any?

    decoded_summary_polyline[0]
  end

  def end_latlng
    return unless decoded_summary_polyline&.any?

    decoded_summary_polyline[-1]
  end

  def image_url
    return unless decoded_summary_polyline&.any?

    google_maps_api_key = ENV.fetch('GOOGLE_STATIC_MAPS_API_KEY', nil)
    "https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&path=enc:#{summary_polyline}&key=#{google_maps_api_key}&size=800x800&markers=color:yellow|label:S|#{start_latlng[0]},#{start_latlng[1]}&markers=color:green|label:F|#{end_latlng[0]},#{end_latlng[1]}"
  end

  def proxy_image_url
    "#{SlackRubyBotServer::Service.url}/api/maps/#{id}.png"
  end

  def png_size
    png.data.size if png&.data
  end

  def to_s
    [
      "proxy=#{proxy_image_url}",
      png ? "png=#{png_size} byte(s)" : nil
    ].compact.join(', ')
  end

  def delete_png!
    update_attributes!(png: nil)
  end

  private

  def update_decoded_summary_polyline
    unless summary_polyline && (summary_polyline_changed? || saved_change_to_summary_polyline? || decoded_summary_polyline.nil?)
      return
    end

    update_decoded_summary_polyline!
  end

  def update_decoded_summary_polyline!
    return if summary_polyline.blank?

    self.decoded_summary_polyline = Polylines::Decoder.decode_polyline(summary_polyline)
  end

  def update_png!
    url = image_url
    return unless url

    body = HTTParty.get(url).body
    self.png = BSON::Binary.new(body)
  end

  def update_png
    return if png_changed? || saved_change_to_png?
    return unless summary_polyline_changed? || saved_change_to_summary_polyline? || png.nil?
    return unless user_activity.user.team.proxy_maps

    update_png!
  end
end
