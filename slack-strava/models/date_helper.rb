module DateHelper
  def format_date(time)
    time.midnight == time ? time.strftime('%B %d, %Y') : time.to_fs(:long)
  end
end
