require 'spec_helper'

describe 'Subscribe', js: true, type: :feature do
  context 'without team_id' do
    before do
      visit '/subscribe'
    end
    it 'requires a team' do
      expect(find('#messages')).to have_text('Missing or invalid team ID.')
      find('#subscribe', visible: false)
    end
  end
  context 'for a subscribed team' do
    let!(:team) { Fabricate(:team, subscribed: true) }
    before do
      visit "/subscribe?team_id=#{team.team_id}"
    end
    it 'displays an error' do
      expect(find('#messages')).to have_text("Team #{team.name} is already subscribed, thank you for your support.")
      find('#subscribe', visible: false)
    end
  end
  context 'for a team' do
    let!(:team) { Fabricate(:team) }
    before do
      ENV['STRIPE_API_PUBLISHABLE_KEY'] = 'pk_test_804U1vUeVeTxBl8znwriXskf'
    end
    after do
      ENV.delete 'STRIPE_API_PUBLISHABLE_KEY'
    end
    it 'subscribes team' do
      visit "/subscribe?team_id=#{team.team_id}"
      expect(find('#messages')).to have_text("Subscribe team #{team.name} for $9.99/yr.")

      allow_any_instance_of(Team).to receive(:inform_everyone!)

      find('#subscribe', visible: true)

      expect(Stripe::Customer).to receive(:create).and_return('id' => 'customer_id')

      find('#subscribeButton').click

      sleep 1

      stripe_iframe = all('iframe[name=stripe_checkout_app]').last
      Capybara.within_frame stripe_iframe do
        page.find_field('Email').set 'foo@bar.com'
        page.find_field('Card number').client_set '4242 4242 4242 4242'
        page.find_field('MM / YY').client_set '12/42'
        page.find_field('CVC').set '123'
        find('button[type="submit"]').click
      end

      sleep 5

      find('#subscribe', visible: false)
      expect(find('#messages')).to have_text("Team #{team.name} successfully subscribed.\n\nThank you for your support!")

      team.reload
      expect(team.subscribed).to be true
      expect(team.stripe_customer_id).to eq 'customer_id'
    end
  end
end
