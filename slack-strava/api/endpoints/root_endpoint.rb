module Api
  module Endpoints
    class RootEndpoint < Grape::API
      include Api::Helpers::ErrorHelpers

      prefix 'api'

      format :json
      formatter :json, Grape::Formatter::Roar
      get do
        present self, with: Api::Presenters::RootPresenter
      end

      mount Api::Endpoints::StatusEndpoint
      mount Api::Endpoints::TeamsEndpoint
      mount Api::Endpoints::UsersEndpoint
      mount Api::Endpoints::SubscriptionsEndpoint
      mount Api::Endpoints::CreditCardsEndpoint
      mount Api::Endpoints::MapsEndpoint
      mount Api::Endpoints::SlackEndpoint

      add_swagger_documentation
    end
  end
end
