require 'spec_helper'

describe MapTypes do
  describe '#parse_s' do
    it 'returns nil for nil' do
      expect(described_class.parse_s(nil)).to be_nil
    end

    it 'returns off' do
      expect(described_class.parse_s('off')).to eq(MapTypes::OFF)
    end

    it 'returns full' do
      expect(described_class.parse_s('full')).to eq(MapTypes::FULL)
    end

    it 'raise an error on an invalid value' do
      expect { described_class.parse_s('invalid') }.to raise_error SlackStrava::Error, 'Invalid value: invalid, possible values are full, off and thumb.'
    end
  end
end
