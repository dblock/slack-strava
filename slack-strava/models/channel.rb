class Channel
  include Mongoid::Document
  include Mongoid::Timestamps

  field :channel_id, type: String
  field :channel_name, type: String
  field :activity_types, type: Array, default: []
  field :maps, type: String
  field :units, type: String
  field :activity_fields, type: Array
  field :threads, type: String
  field :max_activities_per_user_per_day, type: Integer

  belongs_to :team

  index({ team_id: 1, channel_id: 1 }, unique: true)

  validates_presence_of :team_id, :channel_id

  def activity_types_s
    activity_types.blank? ? 'all' : activity_types.join(', ')
  end

  def maps_s
    { 'off' => 'not displayed', 'full' => 'displayed in full', 'thumb' => 'displayed as thumbnails' }[maps]
  end

  def units_s
    {
      'mi' => 'miles, feet, yards, and degrees Fahrenheit',
      'km' => 'kilometers, meters, and degrees Celsius',
      'both' => 'both units'
    }[units]
  end

  def activity_fields_s
    return nil if activity_fields.nil?

    case activity_fields
    when ['All'] then 'all displayed if available'
    when ['Default'] then 'set to default'
    when ['None'] then 'not displayed'
    else activity_fields.and
    end
  end

  def threads_s
    case threads
    when 'none' then 'displayed individually'
    when 'daily', 'weekly', 'monthly' then "rolled up in a #{threads} thread"
    end
  end

  def max_activities_per_user_per_day_s
    max_activities_per_user_per_day ? "#{max_activities_per_user_per_day} per day" : nil
  end
end
