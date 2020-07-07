module Api
  module Endpoints
    class StatusEndpoint < Grape::API
      format :json

      namespace :status do
        desc 'Get system status.'
        get do
          present OpenStruct.new(
            stats: SystemStats.latest_or_aggregate!,
            status: Team.asc(:_id).first&.ping!
          ), with: Api::Presenters::StatusPresenter
        end
      end
    end
  end
end
