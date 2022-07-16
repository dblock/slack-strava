module SlackRubyBotServer
  class Service
    LOCALHOST = 'http://localhost:5000'.freeze

    def self.localhost?
      url == LOCALHOST
    end

    def self.url
      ENV.fetch('URL') { (ENV['RACK_ENV'] == 'development' ? LOCALHOST : 'https://slava.playplay.io') }
    end
  end
end
