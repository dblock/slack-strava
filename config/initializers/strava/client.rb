module Strava
  module Api
    module V3
      class Client
        def paginate(method, options = {}, &_block)
          page = 1
          page_size = 10
          loop do
            results = send(method, options.merge(page: page, per_page: page_size))
            results.each do |result|
              yield result
            end
            break if results.size < page_size
            page += 1
          end
        end
      end
    end
  end
end
