module Api
  module Endpoints
    module Requests
      class Request
        attr_reader :token

        def initialize(params)
          @token = params[:token]
        end

        def slack_verification_token!
          unless ENV.key?('SLACK_VERIFICATION_TOKEN') || ENV.key?('SLACK_VERIFICATION_TOKEN_DEV')
            return
          end
          if token == ENV['SLACK_VERIFICATION_TOKEN'] || token == ENV['SLACK_VERIFICATION_TOKEN_DEV']
            return
          end

          throw :error, status: 401, message: 'Message token is not coming from Slack.'
        end

        def logger
          Api::Middleware.logger
        end
      end
    end
  end
end
