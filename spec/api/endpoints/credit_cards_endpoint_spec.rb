require 'spec_helper'

describe Api::Endpoints::CreditCardsEndpoint do
  include Api::Test::EndpointTest

  context 'credit cards' do
    it 'requires stripe parameters' do
      expect { client.credit_cards._post }.to raise_error Faraday::ClientError do |e|
        json = JSON.parse(e.response[:body])
        expect(json['message']).to eq 'Invalid parameters.'
        expect(json['type']).to eq 'param_error'
      end
    end
    context 'premium team without a stripe customer id' do
      let!(:team) { Fabricate(:team, subscribed: true, stripe_customer_id: nil) }
      it 'fails to update credit_card' do
        expect {
          client.credit_cards._post(
            team_id: team._id,
            stripe_token: 'token'
          )
        }.to raise_error Faraday::ClientError do |e|
          json = JSON.parse(e.response[:body])
          expect(json['error']).to eq 'Not a Subscriber'
        end
      end
    end
    context 'existing premium team' do
      include_context :stripe_mock
      let!(:team) { Fabricate(:team) }
      before do
        stripe_helper.create_plan(id: 'slack-strava-yearly', amount: 2999)
        customer = Stripe::Customer.create(
          source: stripe_helper.generate_card_token,
          plan: 'slack-strava-yearly',
          email: 'foo@bar.com'
        )
        expect_any_instance_of(Team).to receive(:inform!).once
        team.update_attributes!(subscribed: true, stripe_customer_id: customer['id'])
      end
      it 'updates a credit card' do
        new_source = stripe_helper.generate_card_token
        client.credit_cards._post(
          team_id: team._id,
          stripe_token: new_source,
          stripe_token_type: 'card'
        )
        team.reload
        customer = Stripe::Customer.retrieve(team.stripe_customer_id)
        expect(customer.source).to eq new_source
      end
    end
  end
end
