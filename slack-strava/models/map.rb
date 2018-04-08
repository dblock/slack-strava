class Map
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :activity

  field :strava_id, type: String
  field :summary_polyline, type: String
  field :decoded_summary_polyline, type: Array
  field :png, type: BSON::Binary

  before_save :update_decoded_summary_polyline
  before_save :update_png

  def self.attrs_from_strava(response)
    {
      strava_id: response['id'],
      summary_polyline: response['summary_polyline']
    }
  end

  def update!
    update_decoded_summary_polyline!
    update_png!
  end

  def image_url
    return unless decoded_summary_polyline
    google_maps_api_key = ENV['GOOGLE_STATIC_MAPS_API_KEY']
    start_latlng = decoded_summary_polyline[0]
    end_latlng = decoded_summary_polyline[-1]
    "https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&path=enc:#{summary_polyline}&key=#{google_maps_api_key}&size=800x800&markers=color:yellow|label:S|#{start_latlng[0]},#{start_latlng[1]}&markers=color:green|label:F|#{end_latlng[0]},#{end_latlng[1]}"
  end

  def proxy_image_url
    "#{SlackStrava::Service.url}/api/maps/#{id}.png"
  end

  def png_size
    return png.data.size if png && png.data
  end

  def to_s
    "proxy=#{proxy_image_url}, png=#{png_size} byte(s)"
  end

  private

  def update_decoded_summary_polyline
    return unless summary_polyline && (summary_polyline_changed? || decoded_summary_polyline.nil?)
    update_decoded_summary_polyline!
  end

  def update_decoded_summary_polyline!
    return unless summary_polyline
    self.decoded_summary_polyline = Polylines::Decoder.decode_polyline(summary_polyline)
  end

  def update_png!
    url = image_url
    return unless url
    body = HTTParty.get(url).body
    self.png = BSON::Binary.new(body)
  end

  def update_png
    return unless summary_polyline_changed? || png.nil?
    update_png!
  end
end
