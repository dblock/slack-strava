class Map
  include Mongoid::Document
  include Mongoid::Timestamps

  field :strava_id, type: String
  field :summary_polyline, type: String
  field :png, type: BSON::Binary

  before_save :update_png

  def decoded_summary_polyline
    Polylines::Decoder.decode_polyline summary_polyline
  end

  def update_png
    return unless summary_polyline_changed? || png.nil?
    body = HTTParty.get(image_url).body
    self.png = BSON::Binary.new(body)
  end

  def image_url
    google_maps_api_key = ENV['GOOGLE_STATIC_MAPS_API_KEY']
    start_latlng = decoded_summary_polyline[0]
    end_latlng = decoded_summary_polyline[-1]
    "https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&path=enc:#{summary_polyline}&key=#{google_maps_api_key}&size=800x800&markers=color:yellow|label:S|#{start_latlng[0]},#{start_latlng[1]}&markers=color:green|label:F|#{end_latlng[0]},#{end_latlng[1]}"
  end

  def proxy_image_url
    "#{SlackStrava::Service.url}/api/maps/#{id}.png"
  end

  def to_s
    "proxy=#{proxy_image_url}, png=#{png.size} byte(s)"
  end
end
