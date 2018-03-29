class Activity < Hashie::Trash
  include Hashie::Extensions::IgnoreUndeclared

  property 'name'
  property 'start_date', transform_with: ->(v) { DateTime.parse(v) }
  property 'start_date_local', transform_with: ->(v) { DateTime.parse(v) }
  property 'start_date_local_s', from: 'start_date_local', with: ->(v) { DateTime.parse(v).strftime('%F %T') }
  property 'distance_in_miles', from: 'distance', with: ->(v) { v * 0.00062137 }
  property 'distance_in_miles_s', from: 'distance', with: ->(v) { format('%.2fmi', v * 0.00062137) }
  property 'time_in_hours_s', from: 'moving_time', with: ->(v) { format('%dh%02dm%02ds', v / 3600 % 24, v / 60 % 60, v % 60) }
  property 'average_speed_mph_s', from: 'average_speed', with: ->(v) { format('%.2fmph', (v * 2.23694)) }
  property 'pace_per_mile_s', from: 'average_speed', with: ->(v) { Time.at((60 * 60) / (v * 2.23694)).utc.strftime('%M:%S min/mi') }
  property 'summary_polyline', from: 'map', with: ->(v) { v['summary_polyline'] }
  property 'decoded_summary_polyline', from: 'map', with: ->(v) { Polylines::Decoder.decode_polyline(v['summary_polyline']) }
  property 'image_url', from: 'map', with: ->(v) {
    summary_polyline = v['summary_polyline']
    decoded_summary_polyline = Polylines::Decoder.decode_polyline(summary_polyline)
    google_maps_api_key = ENV['GOOGLE_STATIC_MAPS_API_KEY']
    start_latlng = decoded_summary_polyline[0]
    end_latlng = decoded_summary_polyline[-1]
    "https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&path=enc:#{summary_polyline}&key=#{google_maps_api_key}&size=800x800&markers=color:yellow|label:S|#{start_latlng[0]},#{start_latlng[1]}&markers=color:green|label:F|#{end_latlng[0]},#{end_latlng[1]}"
  }

  def to_s
    "name=#{name}, start_date=#{start_date_local_s}, distance=#{distance_in_miles_s}, time=#{time_in_hours_s}, pace=#{pace_per_mile_s}"
  end
end
