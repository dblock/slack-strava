require 'spec_helper'

describe SlackStrava::App do
  subject do
    SlackStrava::App.instance
  end
  context '#instance' do
    it 'is an instance of the strava app' do
      expect(subject).to be_a_kind_of(SlackRubyBotServer::App)
      expect(subject).to be_an_instance_of(SlackStrava::App)
    end
  end
  context '#purge_inactive_teams!' do
    it 'purges teams' do
      expect(Team).to receive(:purge!)
      subject.send(:purge_inactive_teams!)
    end
  end
  context '#deactivate_asleep_teams!' do
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
    include_context :stripe_mock
    let(:plan) { stripe_helper.create_plan(id: 'slava-yearly', amount: 999) }
    let(:customer) { Stripe::Customer.create(source: stripe_helper.generate_card_token, plan: plan.id, email: 'foo@bar.com') }
    let!(:team) { Fabricate(:team, subscribed: true, stripe_customer_id: customer.id) }
    context '#check_subscribed_teams!' do
      it 'ignores active subscriptions' do
        expect_any_instance_of(Team).to_not receive(:inform!)
        expect_any_instance_of(Team).to_not receive(:inform_admin!)
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
      it 'notifies no active subscriptions' do
        customer.subscriptions.data = []
        expect(Stripe::Customer).to receive(:retrieve).and_return(customer)
        expect_any_instance_of(Team).to receive(:inform_admin!).with(text: 'Your subscription was canceled and your team has been downgraded. Thank you for being a customer!')
        subject.send(:check_subscribed_teams!)
        expect(team.reload.subscribed?).to be false
      end
    end
  end
  context '#check_trials!' do
    let!(:active_team) { Fabricate(:team, created_at: Time.now.utc) }
    let!(:active_team_one_week_ago) { Fabricate(:team, created_at: 1.week.ago) }
    let!(:active_team_twelve_days_ago) { Fabricate(:team, created_at: 12.days.ago) }
    it 'notifies teams' do
      expect_any_instance_of(Team).to receive(:inform_everyone!).with(text: active_team_twelve_days_ago.trial_message)
      subject.send(:check_trials!)
    end
  end
end
