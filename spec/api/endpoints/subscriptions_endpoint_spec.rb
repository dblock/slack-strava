require 'spec_helper'

describe Api::Endpoints::SubscriptionsEndpoint do
  include Api::Test::EndpointTest

  context 'subcriptions' do
    it 'requires stripe parameters' do
      expect { client.subscriptions._post }.to raise_error Faraday::ClientError do |e|
        json = JSON.parse(e.response[:body])
        expect(json['message']).to eq 'Invalid parameters.'
        expect(json['type']).to eq 'param_error'
      end
    end

    context 'subscribed team' do
      let!(:team) { Fabricate(:team, subscribed: true) }

      it 'fails to create a subscription' do
        expect {
          client.subscriptions._post(
            team_id: team.team_id,
            stripe_token: 'token',
            stripe_token_type: 'card',
            stripe_email: 'foo@bar.com'
          )
        }.to raise_error Faraday::ClientError do |e|
          json = JSON.parse(e.response[:body])
          expect(json['error']).to eq 'Already Subscribed'
        end
      end
    end

    context 'team with a canceled subscription' do
      let!(:team) { Fabricate(:team, subscribed: false, stripe_customer_id: 'customer_id') }
      let(:stripe_customer) { double(Stripe::Customer) }

      before do
        allow(Stripe::Customer).to receive(:retrieve).with(team.stripe_customer_id).and_return(stripe_customer)
      end

      context 'with an active subscription' do
        before do
          allow(stripe_customer).to receive(:subscriptions).and_return(
            [
              double(Stripe::Subscription)
            ]
          )
        end

        it 'fails to create a subscription' do
          expect {
            client.subscriptions._post(
              team_id: team.team_id,
              stripe_token: 'token',
              stripe_token_type: 'card',
              stripe_email: 'foo@bar.com'
            )
          }.to raise_error Faraday::ClientError do |e|
            json = JSON.parse(e.response[:body])
            expect(json['error']).to eq 'Existing Subscription Already Active'
          end
        end
      end

      context 'without no active subscription' do
        before do
          allow(stripe_customer).to receive(:subscriptions).and_return([])
        end

        it 'updates a subscription' do
          expect(Stripe::Customer).to receive(:update).with(
            team.stripe_customer_id,
            {
              source: 'token',
              plan: 'slava-yearly',
              email: 'foo@bar.com',
              metadata: {
                id: team._id,
                team_id: team.team_id,
                name: team.name,
                domain: team.domain
              }
            }
          ).and_return('id' => 'customer_id')
          expect_any_instance_of(Team).to receive(:inform!).once
          expect_any_instance_of(Team).to receive(:inform_admin!).once
          client.subscriptions._post(
            team_id: team.team_id,
            stripe_token: 'token',
            stripe_token_type: 'card',
            stripe_email: 'foo@bar.com'
          )
          team.reload
          expect(team.subscribed).to be true
          expect(team.subscribed_at).not_to be_nil
          expect(team.stripe_customer_id).to eq 'customer_id'
        end
      end
    end

    context 'existing team' do
      let!(:team) { Fabricate(:team) }

      it 'creates a subscription' do
        expect(Stripe::Customer).to receive(:create).with(
          {
            source: 'token',
            plan: 'slava-yearly',
            email: 'foo@bar.com',
            metadata: {
              id: team._id,
              team_id: team.team_id,
              name: team.name,
              domain: team.domain
            }
          }
        ).and_return('id' => 'customer_id')
        expect_any_instance_of(Team).to receive(:inform!).once
        expect_any_instance_of(Team).to receive(:inform_admin!).once
        client.subscriptions._post(
          team_id: team.team_id,
          stripe_token: 'token',
          stripe_token_type: 'card',
          stripe_email: 'foo@bar.com'
        )
        team.reload
        expect(team.subscribed).to be true
        expect(team.subscribed_at).not_to be_nil
        expect(team.stripe_customer_id).to eq 'customer_id'
      end
    end
  end
end
