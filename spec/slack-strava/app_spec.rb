require 'spec_helper'

describe SlackStrava::App do
  subject do
    described_class.instance
  end

  describe '#instance' do
    it 'is an instance of the strava app' do
      expect(subject).to be_a(SlackRubyBotServer::App)
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe '#purge_inactive_teams!' do
    it 'purges teams' do
      expect(Team).to receive(:purge!)
      subject.send(:purge_inactive_teams!)
    end
  end

  describe '#after_start!' do
    it 'initializes the webhook and statistics and schedules each maintenance interval' do
      task = instance_double(Async::Task)
      allow(Async::Reactor).to receive(:run).and_wrap_original do |_reactor, &job|
        job.call(task)
      end
      allow(Stripe::Subscription).to receive(:list).with(plan: 'slava-yearly').and_return(
        Stripe::ListObject.construct_from(data: [], has_more: false)
      )
      expect(StravaWebhook.instance).to receive(:ensure!).ordered
      [86_400, 3600, 10].each do |interval|
        expect(task).to receive(:sleep).with(interval).ordered.and_raise(StopIteration)
      end
      subject.after_start!
      expect(SystemStats.count).to eq 1
    end
  end

  %i[once_and_every continuously].each do |scheduler|
    describe "##{scheduler}" do
      let(:task) { instance_double(Async::Task) }

      before do
        allow(Async::Reactor).to receive(:run).and_yield(task)
      end

      it 'runs the job and waits the configured interval' do
        yielded = []
        expect(task).to receive(:sleep).with(60).and_raise(StopIteration)
        subject.send(scheduler, 60) { |*args| yielded << args }
        expect(yielded).to eq [scheduler == :continuously ? [task, 60] : []]
      end

      it 'reports failures and continues on the next interval' do
        failure = StandardError.new('maintenance failed')
        attempts = 0
        expect(subject.logger).to receive(:error).with(failure)
        expect(task).to receive(:sleep).with(60).twice.and_invoke(->(_seconds) {}, ->(_seconds) { raise StopIteration })
        subject.send(scheduler, 60) do
          attempts += 1
          raise failure if attempts == 1
        end
        expect(attempts).to eq 2
      end
    end
  end

  describe '#migrate_activity_team_id!' do
    it 'backfills legacy activities without changing activities that already have a team' do
      legacy = Fabricate(:user_activity, user: Fabricate(:user))
      current = Fabricate(:user_activity, user: Fabricate(:user))
      legacy.unset(:team_id)
      subject.send(:migrate_activity_team_id!)
      expect(legacy.reload.team_id).to eq legacy.user.team_id
      expect(current.reload.team_id).to eq current.user.team_id
    end
  end

  describe '#aggregate_stats!' do
    it 'updates the persisted system statistics' do
      Fabricate(:user_activity)
      subject.send(:aggregate_stats!)
      expect(SystemStats.count).to eq 1
    end
  end

  describe '#prune_pngs!' do
    it 'removes only stale cached images, preserving polylines and recent images' do
      stale = Fabricate(:user_activity)
      recent = Fabricate(:user_activity)
      stale.map.set(png: BSON::Binary.new('old image'), png_retrieved_at: 3.weeks.ago)
      recent.map.set(png: BSON::Binary.new('recent image'), png_retrieved_at: 1.day.ago)
      subject.send(:prune_pngs!)
      expect(stale.reload.map.png).to be_nil
      expect(stale.map.summary_polyline).not_to be_nil
      expect(recent.reload.map.png.data).to eq 'recent image'
    end
  end

  describe '#expire_subscriptions!' do
    let!(:expired) { Fabricate(:team, created_at: 3.weeks.ago) }
    let!(:current) { Fabricate(:team) }

    it 'notifies expired installations once and leaves current trials alone' do
      expect_any_instance_of(Team).to receive(:inform_everyone!).with(text: expired.subscribe_text).once
      2.times { subject.send(:expire_subscriptions!) }
      expect(expired.reload.subscription_expired_at).not_to be_nil
      expect(current.reload.subscription_expired_at).to be_nil
    end

    it 'reports notification failures without expiring the installation' do
      failure = StandardError.new('notification failed')
      allow_any_instance_of(Team).to receive(:inform_everyone!).and_raise(failure)
      expect(NewRelic::Agent).to receive(:notice_error).with(failure, custom_params: { team: expired.to_s })
      subject.send(:expire_subscriptions!)
      expect(expired.reload.subscription_expired_at).to be_nil
    end
  end

  describe '#check_stripe_subscribers!' do
    let(:subscription) { Stripe::Subscription.construct_from(id: 'sub-test', customer: 'cus-test', status: 'active', plan: { nickname: 'Slava', amount: 999 }) }
    let(:customer) { Stripe::Customer.construct_from(id: 'cus-test', metadata: { team_id: 'T-test', name: 'Workspace' }, email: 'owner@example.com') }

    before do
      allow(Stripe::Subscription).to receive(:list).with(plan: 'slava-yearly').and_return(
        Stripe::ListObject.construct_from(data: [subscription], has_more: false)
      )
      allow(Stripe::Customer).to receive(:retrieve).with('cus-test').and_return(customer)
    end

    it 'leaves a correctly associated active subscriber unchanged' do
      team = Fabricate(:team, stripe_customer_id: 'cus-test', subscribed: true)
      expect_any_instance_of(Team).not_to receive(:inform_everyone!)
      expect(Stripe::Subscription).not_to receive(:update)
      subject.send(:check_stripe_subscribers!)
      expect(team.reload.subscribed?).to be true
    end

    it 'recovers a subscription association using customer metadata' do
      team = Fabricate(:team, team_id: 'T-test')
      expect_any_instance_of(Team).to receive(:inform_everyone!).with(text: team.subscribed_text)
      subject.send(:check_stripe_subscribers!)
      expect(team.reload.stripe_customer_id).to eq 'cus-test'
      expect(team.subscribed?).to be true
    end

    it 'cancels auto-renewal for an inactive installation with an active subscription' do
      team = Fabricate(:team, stripe_customer_id: 'cus-test', active: false)
      allow(Stripe::Subscription).to receive(:list).with(customer: 'cus-test').and_return([subscription])
      expect(Stripe::Subscription).to receive(:update).with('sub-test', cancel_at_period_end: true)
      subject.send(:check_stripe_subscribers!)
      expect(team.reload.active?).to be false
    end

    it 'does not cancel anything for an inactive installation without an active subscription' do
      Fabricate(:team, stripe_customer_id: 'cus-test', active: false)
      allow(Stripe::Subscription).to receive(:list).with(customer: 'cus-test').and_return([])
      expect(Stripe::Subscription).not_to receive(:update)
      subject.send(:check_stripe_subscribers!)
    end

    it 'warns about a customer that cannot be associated with an installation' do
      expect(subject.logger).to receive(:warn).with(/Cannot find team for Workspace \(T-test\)/)
      subject.send(:check_stripe_subscribers!)
    end

    it 'reports customer lookup failures' do
      failure = StandardError.new('Stripe unavailable')
      allow(Stripe::Customer).to receive(:retrieve).and_raise(failure)
      expect(NewRelic::Agent).to receive(:notice_error).with(failure, custom_params: { team: 'cus-test' })
      subject.send(:check_stripe_subscribers!)
    end
  end

  describe '#users_brag_and_rebrag!' do
    let!(:failed_team) { Fabricate(:team) }
    let!(:affected_users) { Array.new(2) { Fabricate(:user, team: failed_team, access_token: 'strava-token') } }
    let!(:healthy_user) { Fabricate(:user, team: Fabricate(:team), access_token: 'strava-token') }

    it 'stops the failed team immediately and continues healthy installations on later cycles' do
      task = instance_double(Async::Task, sleep: nil)
      synced_users = []
      rebragged_users = []
      allow_any_instance_of(User).to receive(:sync_and_brag!) do |user|
        synced_users << user.id
        user.team.deactivate! if user.team_id == failed_team.id
      end
      allow_any_instance_of(User).to receive(:rebrag!) { |user| rebragged_users << user.id }
      2.times { subject.send(:users_brag_and_rebrag!, task, 0) }
      expect(synced_users).to eq [affected_users.first.id, healthy_user.id, healthy_user.id]
      expect(rebragged_users).to eq [healthy_user.id, healthy_user.id]
    end

    it 'reports a failed team and continues delivery for the next installation' do
      task = instance_double(Async::Task, sleep: nil)
      failure = StandardError.new('delivery failed')
      synced_users = []
      allow_any_instance_of(User).to receive(:sync_and_brag!) do |user|
        raise failure if user.team_id == failed_team.id

        synced_users << user.id
      end
      allow_any_instance_of(User).to receive(:rebrag!)
      expect(NewRelic::Agent).to receive(:notice_error).with(failure, custom_params: { team: failed_team.to_s })
      subject.send(:users_brag_and_rebrag!, task, 0)
      expect(synced_users).to eq [healthy_user.id]
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

    it 'reports failed deactivation notifications without stopping the cron' do
      failure = StandardError.new('notification failed')
      allow_any_instance_of(Team).to receive(:inform_everyone!).and_raise(failure)
      expect(NewRelic::Agent).to receive(:notice_error).with(failure, custom_params: { team: active_team_two_weeks_ago.to_s })
      subject.send(:deactivate_asleep_teams!)
      expect(active_team_two_weeks_ago.reload.active?).to be false
    end
  end

  context 'subscribed' do
    include_context 'stripe mock'
    let(:plan) { stripe_helper.create_plan(id: 'slava-yearly', amount: 999, product: stripe_product.id, nickname: 'Plan') }
    let(:customer) { Stripe::Customer.create(source: stripe_helper.generate_card_token, plan: plan.id, email: 'foo@bar.com') }
    let!(:team) { Fabricate(:team, subscribed: true, stripe_customer_id: customer.id) }

    describe '#check_subscribed_teams!' do
      it 'reports Stripe failures without downgrading the installation' do
        failure = StandardError.new('Stripe unavailable')
        allow(Stripe::Subscription).to receive(:list).and_raise(failure)
        expect(NewRelic::Agent).to receive(:notice_error).with(failure, custom_params: { team: team.to_s })
        subject.send(:check_subscribed_teams!)
        expect(team.reload.subscribed?).to be true
      end

      it 'ignores active subscriptions' do
        expect_any_instance_of(Team).not_to receive(:inform!)
        expect_any_instance_of(Team).not_to receive(:inform_admin!)
        subject.send(:check_subscribed_teams!)
      end

      it 'notifies past due subscription' do
        subscription = customer.subscriptions.data.first
        subscription['status'] = 'past_due'
        allow(Stripe::Subscription).to receive(:list).and_return([subscription])
        expect_any_instance_of(Team).to receive(:inform!).with(text: "Your subscription to Plan ($9.99) is past due. #{team.update_cc_text}")
        expect_any_instance_of(Team).to receive(:inform_admin!).with(text: "Your subscription to Plan ($9.99) is past due. #{team.update_cc_text}")
        subject.send(:check_subscribed_teams!)
        expect(team.reload.past_due_informed_at).not_to be_nil
      end

      it 'does not re-notify past due subscription within 72 hours' do
        team.update_attributes!(past_due_informed_at: 1.hour.ago)
        subscription = customer.subscriptions.data.first
        subscription['status'] = 'past_due'
        allow(Stripe::Subscription).to receive(:list).and_return([subscription])
        expect_any_instance_of(Team).not_to receive(:inform!)
        expect_any_instance_of(Team).not_to receive(:inform_admin!)
        subject.send(:check_subscribed_teams!)
      end

      it 'notifies past due subscription again after 72 hours' do
        team.update_attributes!(past_due_informed_at: 73.hours.ago)
        subscription = customer.subscriptions.data.first
        subscription['status'] = 'past_due'
        allow(Stripe::Subscription).to receive(:list).and_return([subscription])
        expect_any_instance_of(Team).to receive(:inform!).with(text: "Your subscription to Plan ($9.99) is past due. #{team.update_cc_text}")
        expect_any_instance_of(Team).to receive(:inform_admin!).with(text: "Your subscription to Plan ($9.99) is past due. #{team.update_cc_text}")
        subject.send(:check_subscribed_teams!)
      end

      it 'notifies canceled subscription' do
        subscription = customer.subscriptions.data.first
        subscription['status'] = 'canceled'
        allow(Stripe::Subscription).to receive(:list).and_return([subscription])
        team.update_attributes!(past_due_informed_at: 1.hour.ago)
        expect_any_instance_of(Team).to receive(:inform!).with(text: 'Your subscription to Plan ($9.99) was canceled and your team has been downgraded. Thank you for being a customer!')
        expect_any_instance_of(Team).to receive(:inform_admin!).with(text: 'Your subscription to Plan ($9.99) was canceled and your team has been downgraded. Thank you for being a customer!')
        subject.send(:check_subscribed_teams!)
        expect(team.reload.subscribed?).to be false
        expect(team.reload.past_due_informed_at).to be_nil
      end

      it 'skips inactive teams' do
        subscription = customer.subscriptions.data.first
        subscription['status'] = 'canceled'
        expect_any_instance_of(Team).not_to receive(:inform!)
        expect_any_instance_of(Team).not_to receive(:inform_admin!)
        team.update_attributes!(active: false)
        subject.send(:check_subscribed_teams!)
        expect(team.reload.subscribed?).to be true
      end

      it 'notifies no active subscriptions' do
        allow(Stripe::Subscription).to receive(:list).and_return([])
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

    it 'reports failed trial notifications' do
      failure = StandardError.new('notification failed')
      allow_any_instance_of(Team).to receive(:inform_trial!).and_raise(failure)
      expect(NewRelic::Agent).to receive(:notice_error).with(failure, custom_params: { team: active_team_twelve_days_ago.to_s })
      subject.send(:check_trials!)
    end
  end

  describe '#prune_activities!' do
    let!(:first_team) { Fabricate(:team) }
    let!(:second_team) { Fabricate(:team) }

    before do
      allow(Team).to receive_message_chain(:no_timeout, :each)
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
        expect(subject.logger).to receive(:error).with(
          "Strava webhook installation failed (#{{ message: 'Bad Request', errors: [] }.as_json})."
        )
        subject.send(:ensure_strava_webhook!)
      end
    end
  end
end
