SlackRubyBotServer.configure do |config|
  config.server_pages do |pages|
    pages.cache_control = 'private, no-cache'
    # Template mtimes do not track partials or nested artwork.
    pages.after { response.headers.delete('last-modified') }
  end
end
