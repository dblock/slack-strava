require 'spec_helper'

describe SlackStrava::Commands::Resubscribe, vcr: { cassette_name: 'slack/user_info' } do
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }

  shared_examples_for 'resubscribe' do
    context 'on trial' do
      before do
        team.update_attributes!(subscribed: false, subscribed_at: nil)
      end

      it 'displays all set message' do
        expect(message: "#{SlackRubyBot.config.user} resubscribe").to respond_with_slack_message "You don't have a paid subscription.\n#{team.subscribe_text}"
      end
    end

    context 'with subscribed_at' do
      before do
        team.update_attributes!(subscribed: true, subscribed_at: 1.year.ago)
      end

      it 'displays subscription info' do
        expect(message: "#{SlackRubyBot.config.user} resubscribe").to respond_with_slack_message "You don't have a paid subscription.\n#{team.subscribe_text}"
      end
    end

    context 'with a plan' do
      include_context 'stripe mock'
      before do
        stripe_helper.create_plan(id: 'slava-yearly', amount: 999, name: 'Plan')
      end

      context 'a customer' do
        let!(:customer) do
          Stripe::Customer.create(
            source: stripe_helper.generate_card_token,
            plan: 'slava-yearly',
            email: 'foo@bar.com'
          )
        end
        let(:current_period_end) { Time.at(active_subscription.current_period_end).strftime('%B %d, %Y') }
        let(:activated_user) { Fabricate(:user) }
        let(:active_subscription) { team.active_stripe_subscription }

        before do
          team.update_attributes!(
            subscribed: true,
            stripe_customer_id: customer['id'],
            activated_user_id: activated_user.user_id
          )
          active_subscription.delete(at_period_end: true)
        end

        it 'displays subscription info' do
          customer_info = [
            "Subscribed to Plan ($9.99), will not auto-renew on #{current_period_end}.",
            "Send `resubscribe #{active_subscription.id}` to resubscribe."
          ].join("\n")
          expect(message: "#{SlackRubyBot.config.user} resubscribe", user: activated_user.user_name).to respond_with_slack_message customer_info
        end

        it 'cannot resubscribe with an invalid subscription id' do
          expect(message: "#{SlackRubyBot.config.user} resubscribe xyz", user: activated_user.user_name).to respond_with_slack_message 'Sorry, I cannot find a subscription with "xyz".'
        end

        it 'resubscribes' do
          expect(message: "#{SlackRubyBot.config.user} resubscribe #{active_subscription.id}", user: activated_user.user_name).to respond_with_slack_message 'Successfully enabled auto-renew for Plan ($9.99).'
          team.reload
          expect(team.subscribed).to be true
          expect(team.stripe_customer_id).not_to be_nil
        end

        context 'not an admin' do
          let!(:user) { Fabricate(:user, is_admin: false, is_owner: false, team: team) }

          before do
            expect(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
          end

          it 'cannot resubscribe' do
            expect(message: "#{SlackRubyBot.config.user} resubscribe xyz").to respond_with_slack_message "Sorry, only <@#{activated_user.user_id}> or a Slack admin can do that."
          end
        end
      end
    end
  end

  context 'subscribed team' do
    let!(:team) { Fabricate(:team, subscribed: true) }
    let!(:activated_user) { Fabricate(:user, team: team) }

    before do
      team.update_attributes!(activated_user_id: activated_user.user_id)
    end

    it_behaves_like 'resubscribe'
    context 'with another team' do
      let!(:team2) { Fabricate(:team) }

      it_behaves_like 'resubscribe'
    end
  end
end
