require 'spec_helper'

describe Map do
  let(:activity) { Fabricate(:user_activity) }
  let(:map) { activity.map }

  context 'to_s' do
    context 'without png' do
      it 'includes proxy URL' do
        expect(map.to_s).to eq "proxy=https://slava.playplay.io/api/maps/#{map.id}.png"
      end
    end

    context 'with png' do
      before do
        map.png = BSON::Binary.new(SecureRandom.hex)
      end

      it 'includes proxy URL' do
        expect(map.to_s).to eq "proxy=https://slava.playplay.io/api/maps/#{map.id}.png, png=32 byte(s)"
      end
    end
  end
end
