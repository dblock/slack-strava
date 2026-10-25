require 'spec_helper'

describe StravaWebhook do
  subject(:webhook) { described_class.new }

  let(:subscription) { Hashie::Mash.new(id: 123, callback_url: webhook.callback_url) }
  let(:other_subscription) { Hashie::Mash.new(id: 456, callback_url: 'https://other.example.com/events') }

  describe '#ensure!' do
    it 'creates a verified subscription when only unrelated callbacks exist' do
      allow(webhook.client).to receive(:push_subscriptions).and_return([other_subscription])
      allow(webhook.client).to receive(:create_push_subscription).with(
        callback_url: "#{SlackRubyBotServer::Service.url}/api/strava/event",
        verify_token: webhook.verify_token
      ).and_return(subscription)
      webhook.ensure!
      expect(webhook.subscription.id).to eq 123
      expect(webhook).to be_subscribed
    end

    it 'reuses the matching subscription without creating a duplicate' do
      allow(webhook.client).to receive(:push_subscriptions).and_return([other_subscription, subscription])
      expect(webhook.client).not_to receive(:create_push_subscription)
      2.times { webhook.ensure! }
      expect(webhook.subscription.id).to eq 123
    end

    it 'propagates registration failures instead of caching a successful installation' do
      allow(webhook.client).to receive(:push_subscriptions).and_return([])
      failure = Strava::Errors::Fault.new(400, body: { 'message' => 'Bad Request', 'errors' => [] })
      allow(webhook.client).to receive(:create_push_subscription).and_raise(failure)
      expect { webhook.ensure! }.to raise_error(failure)
      expect(webhook).not_to be_subscribed
    end
  end

  describe '#unsubscribe!' do
    it 'deletes the matching subscription and invalidates the cached subscription' do
      allow(webhook.client).to receive(:push_subscriptions).and_return([subscription])
      expect(webhook.subscription.id).to eq 123
      expect(webhook.client).to receive(:delete_push_subscription).with(id: 123)
      webhook.unsubscribe!
      allow(webhook.client).to receive(:push_subscriptions).and_return([])
      expect(webhook).not_to be_subscribed
    end
  end
end
