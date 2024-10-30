require 'spec_helper'

describe 'Connect', :js, type: :feature do
  context 'without a user' do
    before do
      visit '/connect'
    end

    it 'requires a user' do
      expect(find_by_id('messages')).to have_text('Missing or invalid parameters.')
    end
  end

  [
    Faker::Internet.user_name,
    "#{Faker::Internet.user_name}'s",
    '💥 bob',
    'ваня',
    "\"#{Faker::Internet.user_name}'s\"",
    "#{Faker::Name.first_name} #{Faker::Name.last_name}",
    "#{Faker::Name.first_name}\n#{Faker::Name.last_name}",
    "<script>alert('xss');</script>",
    '<script>alert("xss");</script>'
  ].each do |user_name|
    context "user #{user_name}" do
      let!(:user) { Fabricate(:user, user_name: user_name) }

      it 'displays connect page and connects user' do
        allow(User).to receive(:where).with({ id: user.id }).and_return([user])
        expect(user).to receive(:connect!).with('code')
        visit "/connect?state=#{user.id}&code=code"
        expect(find_by_id('messages')).to have_text("Successfully connected #{user.user_name.gsub("\n", ' ')} to Strava.")
      end
    end
  end
end
