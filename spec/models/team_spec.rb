require 'spec_helper'

describe Team do
  context '#find_or_create_from_env!' do
    before do
      ENV['SLACK_API_TOKEN'] = 'token'
    end
    context 'team', vcr: { cassette_name: 'slack/team_info' } do
      it 'creates a team' do
        expect { Team.find_or_create_from_env! }.to change(Team, :count).by(1)
        team = Team.first
        expect(team.team_id).to eq 'T04KB5WQH'
        expect(team.name).to eq 'dblock'
        expect(team.domain).to eq 'dblockdotorg'
        expect(team.token).to eq 'token'
      end
    end
    after do
      ENV.delete 'SLACK_API_TOKEN'
    end
  end
  context '#purge!' do
    let!(:active_team) { Fabricate(:team) }
    let!(:inactive_team) { Fabricate(:team, active: false) }
    let!(:inactive_team_one_week_ago) { Fabricate(:team, updated_at: 1.week.ago, active: false) }
    let!(:inactive_team_two_weeks_ago) { Fabricate(:team, updated_at: 2.weeks.ago, active: false) }
    let!(:inactive_team_a_month_ago) { Fabricate(:team, updated_at: 1.month.ago, active: false) }
    it 'destroys teams inactive for two weeks' do
      expect {
        Team.purge!
      }.to change(Team, :count).by(-2)
      expect(Team.find(active_team.id)).to eq active_team
      expect(Team.find(inactive_team.id)).to eq inactive_team
      expect(Team.find(inactive_team_one_week_ago.id)).to eq inactive_team_one_week_ago
      expect(Team.find(inactive_team_two_weeks_ago.id)).to be nil
      expect(Team.find(inactive_team_a_month_ago.id)).to be nil
    end
  end
  context '#asleep?' do
    context 'default' do
      let(:team) { Fabricate(:team, created_at: Time.now.utc) }
      it 'false' do
        expect(team.asleep?).to be false
      end
    end
    context 'team created two weeks ago' do
      let(:team) { Fabricate(:team, created_at: 2.weeks.ago) }
      it 'is asleep' do
        expect(team.asleep?).to be true
      end
    end
    context 'team created two weeks ago and subscribed' do
      let(:team) { Fabricate(:team, created_at: 2.weeks.ago, subscribed: true) }
      before do
        allow(team).to receive(:inform_subscribed_changed!)
        team.update_attributes!(subscribed: true)
      end
      it 'is not asleep' do
        expect(team.asleep?).to be false
      end
      it 'resets subscription_expired_at' do
        expect(team.subscription_expired_at).to be nil
      end
    end
    context 'team created over two weeks ago' do
      let(:team) { Fabricate(:team, created_at: 2.weeks.ago - 1.day) }
      it 'is asleep' do
        expect(team.asleep?).to be true
      end
    end
    context 'team created over two weeks ago and subscribed' do
      let(:team) { Fabricate(:team, created_at: 2.weeks.ago - 1.day, subscribed: true) }
      it 'is not asleep' do
        expect(team.asleep?).to be false
      end
    end
  end
  context '#subscription_expired!' do
    let(:team) { Fabricate(:team, created_at: 2.weeks.ago) }
    before do
      expect(team).to receive(:inform!).with(text: team.subscribe_text)
      expect(team).to receive(:inform_admin!).with(text: team.subscribe_text)
      team.subscription_expired!
    end
    it 'sets subscription_expired_at' do
      expect(team.subscription_expired_at).to_not be nil
    end
    context '(re)subscribed' do
      before do
        expect(team).to receive(:inform!).with(text: team.subscribed_text)
        expect(team).to receive(:inform_admin!).with(text: team.subscribed_text)
        team.update_attributes!(subscribed: true)
      end
      it 'resets subscription_expired_at' do
        expect(team.subscription_expired_at).to be nil
      end
    end
  end
  context '#inform!' do
    let(:team) { Fabricate(:team) }
    it 'sends message to all channels', vcr: { cassette_name: 'slack/channels_list' } do
      expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).exactly(3).times.and_return('ts' => '1503435956.000247')
      team.inform!(message: 'message')
    end
  end
  context 'subscribed states' do
    let(:today) { DateTime.parse('2018/7/15 12:42pm') }
    let(:subscribed_team) { Fabricate(:team, subscribed: true) }
    let(:team_created_today) { Fabricate(:team, created_at: today) }
    let(:team_created_1_week_ago) { Fabricate(:team, created_at: (today - 1.week)) }
    let(:team_created_3_weeks_ago) { Fabricate(:team, created_at: (today - 3.weeks)) }
    before do
      Timecop.travel(today + 1.day)
    end
    it 'subscription_expired?' do
      expect(subscribed_team.subscription_expired?).to be false
      expect(team_created_1_week_ago.subscription_expired?).to be false
      expect(team_created_3_weeks_ago.subscription_expired?).to be true
    end
    it 'trial_ends_at' do
      expect { subscribed_team.trial_ends_at }.to raise_error 'Team is subscribed.'
      expect(team_created_today.trial_ends_at).to eq team_created_today.created_at + 2.weeks
      expect(team_created_1_week_ago.trial_ends_at).to eq team_created_1_week_ago.created_at + 2.weeks
      expect(team_created_3_weeks_ago.trial_ends_at).to eq team_created_3_weeks_ago.created_at + 2.weeks
    end
    it 'remaining_trial_days' do
      expect { subscribed_team.remaining_trial_days }.to raise_error 'Team is subscribed.'
      expect(team_created_today.remaining_trial_days).to eq 13
      expect(team_created_1_week_ago.remaining_trial_days).to eq 6
      expect(team_created_3_weeks_ago.remaining_trial_days).to eq 0
    end
    context '#inform_trial!' do
      it 'subscribed' do
        expect(subscribed_team).to_not receive(:inform!)
        expect(subscribed_team).to_not receive(:inform_admin!)
        subscribed_team.inform_trial!
      end
      it '1 week ago' do
        expect(team_created_1_week_ago).to receive(:inform!).with(
          text: "Your trial subscription expires in 6 days. #{team_created_1_week_ago.subscribe_text}"
        )
        expect(team_created_1_week_ago).to receive(:inform_admin!).with(
          text: "Your trial subscription expires in 6 days. #{team_created_1_week_ago.subscribe_text}"
        )
        team_created_1_week_ago.inform_trial!
      end
      it 'expired' do
        expect(team_created_3_weeks_ago).to_not receive(:inform!)
        expect(team_created_3_weeks_ago).to_not receive(:inform_admin!)
        team_created_3_weeks_ago.inform_trial!
      end
      it 'informs once' do
        expect(team_created_1_week_ago).to receive(:inform!).once
        expect(team_created_1_week_ago).to receive(:inform_admin!).once
        2.times { team_created_1_week_ago.inform_trial! }
      end
    end
    after do
      Timecop.return
    end
  end
end
