require 'spec_helper'

describe 'Update cc', js: true, type: :feature do
  context 'with a stripe key' do
    before do
      ENV['STRIPE_API_PUBLISHABLE_KEY'] = 'pk_test_804U1vUeVeTxBl8znwriXskf'
    end
    after do
      ENV.delete 'STRIPE_API_PUBLISHABLE_KEY'
    end
    context 'with an invalid team ID' do
      it 'displays error' do
        visit '/update_cc?team_id=invalid'
        expect(find('#messages')).to have_text('Team not found.')
      end
    end
    context 'a team with a stripe customer ID' do
      let!(:team) { Fabricate(:team, stripe_customer_id: 'stripe_customer_id') }
      it 'updates cc' do
        visit "/update_cc?team_id=#{team.team_id}"
        expect(find('h1')).to have_text('Slava: Update Credit Card Info')
        customer = double
        expect(Stripe::Customer).to receive(:retrieve).and_return(customer)
        expect(customer).to receive(:source=)
        expect(customer).to receive(:save)
        click_button 'Update Credit Card'
        sleep 1
        stripe_iframe = all('iframe[name=stripe_checkout_app]').last
        Capybara.within_frame stripe_iframe do
          page.find_field('Email').set 'foo@bar.com'
          page.find_field('Card number').client_set '4012 8888 8888 1881'
          page.find_field('MM / YY').client_set '12/42'
          page.find_field('CVC').set '345'
          find('button[type="submit"]').click
        end
        sleep 5
        find('#update_cc', visible: false)
        expect(find('#messages')).to have_text("Successfully updated team #{team.name} credit card.\n\nThank you for your support!")
      end
    end
    context 'a team without a stripe customer ID' do
      let!(:team) { Fabricate(:team, stripe_customer_id: nil) }
      it 'displays error' do
        visit "/update_cc?team_id=#{team.team_id}"
        expect(find('h1')).to have_text('Slava: Update Credit Card Info')
        click_button 'Update Credit Card'
        sleep 1
        stripe_iframe = all('iframe[name=stripe_checkout_app]').last
        Capybara.within_frame stripe_iframe do
          page.find_field('Email').set 'foo@bar.com'
          page.find_field('Card number').client_set '4012 8888 8888 1881'
          page.find_field('MM / YY').client_set '12/42'
          page.find_field('CVC').set '345'
          find('button[type="submit"]').click
        end
        sleep 5
        find('#update_cc', visible: false)
        expect(find('#messages')).to have_text('Not a Subscriber')
      end
    end
  end
end
