require 'spec_helper'

describe Api::Helpers::CursorHelpers do
  include Rack::Test::Methods

  let(:app) do
    Class.new(Grape::API) do
      format :json
      include Api::Helpers::ErrorHelpers

      helpers Api::Helpers::SortHelpers
      helpers Api::Helpers::CursorHelpers

      route_setting :sort, sort: %w[name -name -]
      params do
        optional :sort, type: String
        optional :size, type: Integer
        optional :offset, type: Integer
        optional :cursor, type: String
        optional :total_count, type: Grape::API::Boolean
      end
      get :teams do
        page = paginate_and_sort_by_cursor(Team, default_sort_order: 'name')
        { names: page.results.map(&:name), next: page.next, total_count: page.total_count }
      end

      get(:unsorted) { { names: sort(Team).map(&:name) } }
      get(:unsortable) { sort([], default_sort_order: 'name') }

      route_setting :sort, sort: ['name']
      get(:single_sort) { sort(Team, default_sort_order: 'name') }

      post(:invalid_record) { Team.create!(token: nil, team_id: nil) }
      get(:invalid_parameter) { raise Grape::Exceptions::Validation.new(params: ['sort'], message: 'Unsupported sort') }
    end
  end
  let!(:teams) { %w[Alpha Charlie Bravo].map { |name| Fabricate(:team, name: name) } }

  def response
    JSON.parse(last_response.body)
  end

  it 'sorts ascending and resumes from the next cursor' do
    get '/teams', size: 1
    expect(response['names']).to eq ['Alpha']
    cursor = response['next']
    get '/teams', size: 1, cursor: cursor
    expect(response['names']).to eq ['Bravo']
  end

  it 'supports an explicitly allowed descending order' do
    get '/teams', sort: '-name'
    expect(last_response.status).to eq 200
    expect(response['names']).to eq %w[Charlie Bravo Alpha]
  end

  it 'skips records with an offset' do
    get '/teams', offset: 1, size: 1
    expect(response['names']).to eq ['Bravo']
  end

  it 'returns the total count independently of page size' do
    get '/teams', total_count: true, size: 1
    expect(response['names'].size).to eq 1
    expect(response['total_count']).to eq 3
  end

  it 'rejects a cursor combined with an offset' do
    get '/teams', cursor: 'cursor', offset: 1
    expect(last_response.status).to eq 400
    expect(response['message']).to include('mutually exclusive')
  end

  it 'rejects unsupported sort columns with the permitted choices' do
    get '/teams', sort: 'token'
    expect(last_response.status).to eq 400
    expect(response['error']).to eq "Invalid sort order: token, must be one of 'name', '-name', '-'"
  end

  it 'rejects a direction without a column' do
    get '/teams', sort: '-'
    expect(last_response.status).to eq 400
    expect(response['error']).to eq 'Invalid sort: -'
  end

  it 'rejects sorting on routes without declared sort orders' do
    get '/unsorted', sort: 'name'
    expect(last_response.status).to eq 400
    expect(response['error']).to eq "This API doesn't support sorting"
  end

  it 'reports collections that cannot support the requested sort' do
    get '/unsortable'
    expect(last_response.status).to eq 500
    expect(response['error']).to eq 'Cannot sort Array'
  end

  it 'describes a single permitted sort order' do
    get '/single_sort', sort: '-name'
    expect(last_response.status).to eq 400
    expect(response['error']).to eq "Invalid sort order: -name, must be 'name'"
  end

  it 'accepts an unsorted model collection when no order is requested' do
    get '/unsorted'
    expect(response['names']).to match_array teams.map(&:name)
  end

  it 'formats model validation failures as structured parameter errors' do
    post '/invalid_record'
    expect(last_response.status).to eq 400
    expect(response['type']).to eq 'param_error'
    expect(response['detail']['token']).to include("can't be blank")
  end

  it 'formats individual Grape parameter failures consistently' do
    get '/invalid_parameter'
    expect(last_response.status).to eq 400
    expect(response).to include('type' => 'param_error', 'message' => 'Invalid parameters.', 'detail' => { 'sort' => ['Unsupported sort'] })
  end
end
