require 'spec_helper'

describe SlackStrava::App do
  subject do
    SlackStrava::App.instance
  end

  describe '#instance' do
    it 'is an instance of the strava app' do
      expect(subject).to be_a(SlackRubyBotServer::App)
      expect(subject).to be_an_instance_of(SlackStrava::App)
    end
  end

  describe '#purge_inactive_teams!' do
    it 'purges teams' do
      expect(Team).to receive(:purge!)
      subject.send(:purge_inactive_teams!)
    end
  end

  describe '#deactivate_asleep_teams!' do
    let!(:active_team) { Fabricate(:team, created_at: Time.now.utc) }
    let!(:active_team_one_week_ago) { Fabricate(:team, created_at: 1.week.ago) }
    let!(:active_team_two_weeks_ago) { Fabricate(:team, created_at: 2.weeks.ago) }
    let!(:subscribed_team_a_month_ago) { Fabricate(:team, created_at: 1.month.ago, subscribed: true) }

    it 'destroys teams inactive for two weeks' do
      expect_any_instance_of(Team).to receive(:inform!).with(
        text: "Your subscription expired more than 2 weeks ago, deactivating. Reactivate at #{SlackRubyBotServer::Service.url}. Your data will be purged in another 2 weeks."
      ).once
      expect_any_instance_of(Team).to receive(:inform_admin!).with(
        text: "Your subscription expired more than 2 weeks ago, deactivating. Reactivate at #{SlackRubyBotServer::Service.url}. Your data will be purged in another 2 weeks."
      ).once
      subject.send(:deactivate_asleep_teams!)
      expect(active_team.reload.active).to be true
      expect(active_team_one_week_ago.reload.active).to be true
      expect(active_team_two_weeks_ago.reload.active).to be false
      expect(subscribed_team_a_month_ago.reload.active).to be true
    end
  end

  context 'subscribed' do
    include_context 'stripe mock'
    let(:plan) { stripe_helper.create_plan(id: 'slava-yearly', amount: 999) }
    let(:customer) { Stripe::Customer.create(source: stripe_helper.generate_card_token, plan: plan.id, email: 'foo@bar.com') }
    let!(:team) { Fabricate(:team, subscribed: true, stripe_customer_id: customer.id) }

    describe '#check_subscribed_teams!' do
      it 'ignores active subscriptions' do
        expect_any_instance_of(Team).not_to receive(:inform!)
        expect_any_instance_of(Team).not_to receive(:inform_admin!)
        subject.send(:check_subscribed_teams!)
      end

      it 'notifies past due subscription' do
        customer.subscriptions.data.first['status'] = 'past_due'
        expect(Stripe::Customer).to receive(:retrieve).and_return(customer)
        expect_any_instance_of(Team).to receive(:inform!).with(text: "Your subscription to StripeMock Default Plan ID ($9.99) is past due. #{team.update_cc_text}")
        expect_any_instance_of(Team).to receive(:inform_admin!).with(text: "Your subscription to StripeMock Default Plan ID ($9.99) is past due. #{team.update_cc_text}")
        subject.send(:check_subscribed_teams!)
      end

      it 'notifies canceled subscription' do
        customer.subscriptions.data.first['status'] = 'canceled'
        expect(Stripe::Customer).to receive(:retrieve).and_return(customer)
        expect_any_instance_of(Team).to receive(:inform!).with(text: 'Your subscription to StripeMock Default Plan ID ($9.99) was canceled and your team has been downgraded. Thank you for being a customer!')
        expect_any_instance_of(Team).to receive(:inform_admin!).with(text: 'Your subscription to StripeMock Default Plan ID ($9.99) was canceled and your team has been downgraded. Thank you for being a customer!')
        subject.send(:check_subscribed_teams!)
        expect(team.reload.subscribed?).to be false
      end

      it 'skips inactive teams' do
        customer.subscriptions.data.first['status'] = 'canceled'
        expect_any_instance_of(Team).not_to receive(:inform!)
        expect_any_instance_of(Team).not_to receive(:inform_admin!)
        team.update_attributes!(active: false)
        subject.send(:check_subscribed_teams!)
        expect(team.reload.subscribed?).to be true
      end

      it 'notifies no active subscriptions' do
        customer.subscriptions.data = []
        expect(Stripe::Customer).to receive(:retrieve).and_return(customer)
        expect_any_instance_of(Team).to receive(:inform_admin!).with(text: 'Your subscription was canceled and your team has been downgraded. Thank you for being a customer!')
        subject.send(:check_subscribed_teams!)
        expect(team.reload.subscribed?).to be false
      end
    end
  end

  describe '#check_trials!' do
    let!(:active_team) { Fabricate(:team, created_at: Time.now.utc) }
    let!(:active_team_one_week_ago) { Fabricate(:team, created_at: 1.week.ago) }
    let!(:active_team_twelve_days_ago) { Fabricate(:team, created_at: 12.days.ago) }

    it 'notifies teams' do
      expect_any_instance_of(Team).to receive(:inform_everyone!).with(text: active_team_twelve_days_ago.trial_message)
      subject.send(:check_trials!)
    end
  end

  describe '#prune_activities!' do
    let!(:first_team) { Fabricate(:team) }
    let!(:second_team) { Fabricate(:team) }

    before do
      allow(Team).to receive(:each)
        .and_yield(first_team)
        .and_yield(second_team)
    end

    it 'calls prune_activities! on each team' do
      expect(first_team).to receive(:prune_activities!)
      expect(second_team).to receive(:prune_activities!)
      expect(subject.logger).to receive(:info).with(/Pruning activities for \d+ team\(s\)\./)
      expect(subject.logger).to receive(:info).with(%r{Pruned \d+/\d+ activities\.})
      subject.send(:prune_activities!)
    end

    context 'with error during pruning' do
      before do
        allow_any_instance_of(Team).to receive(:prune_activities!).and_raise('Error')
      end

      it 'logs error and continues' do
        expect(subject.logger).to receive(:warn).with(/Error pruning team .*, Error/).twice
        expect(NewRelic::Agent).to receive(:notice_error).twice
        subject.send(:prune_activities!)
      end
    end
  end

  describe '#ensure_strava_webhook!' do
    let(:webhook_instance) { StravaWebhook.instance }

    context 'on localhost' do
      before do
        allow(SlackRubyBotServer::Service).to receive(:localhost?).and_return(true)
      end

      it 'is skipped' do
        expect(webhook_instance).not_to receive(:ensure!)
        subject.send(:ensure_strava_webhook!)
      end
    end

    context 'not on localhost' do
      before do
        allow(SlackRubyBotServer::Service).to receive(:localhost?).and_return(false)
      end

      it 'is ensured' do
        allow(SlackRubyBotServer::Service).to receive(:localhost?).and_return(false)
        expect(webhook_instance).to receive(:ensure!)
        subject.send(:ensure_strava_webhook!)
      end

      it 'handles Strava::Errors::Fault' do
        allow(SlackRubyBotServer::Service).to receive(:localhost?).and_return(false)
        expect(webhook_instance).to receive(:ensure!).and_raise(
          Strava::Errors::Fault.new(
            400,
            body: {
              'message' => 'Bad Request',
              'errors' => []
            }
          )
        )
        expect(subject.logger).to receive(:error).with('Strava webhook installation failed ({"message"=>"Bad Request", "errors"=>[]}).')
        subject.send(:ensure_strava_webhook!)
      end
    end
  end
end
