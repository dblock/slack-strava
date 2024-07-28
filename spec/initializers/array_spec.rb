require 'spec_helper'

describe Array do
  describe '.and' do
    it 'one' do
      expect(['foo'].and).to eq 'foo'
    end

    it 'two' do
      expect(%w[foo bar].and).to eq 'foo and bar'
    end

    it 'three' do
      expect(%w[foo bar baz].and).to eq 'foo, bar and baz'
    end

    it 'one with block' do
      expect(['foo'].and { |i| "<b>#{i}</b>" }).to eq '<b>foo</b>'
    end

    it 'two with block' do
      expect(%w[foo bar].and { |i| "<b>#{i}</b>" }).to eq '<b>foo</b> and <b>bar</b>'
    end

    it 'three with block' do
      expect(%w[foo bar baz].and { |i| "<b>#{i}</b>" }).to eq '<b>foo</b>, <b>bar</b> and <b>baz</b>'
    end
  end

  describe '.or' do
    it 'one' do
      expect(['foo'].or).to eq 'foo'
    end

    it 'two' do
      expect(%w[foo bar].or).to eq 'foo or bar'
    end

    it 'three' do
      expect(%w[foo bar baz].or).to eq 'foo, bar or baz'
    end
  end
end
