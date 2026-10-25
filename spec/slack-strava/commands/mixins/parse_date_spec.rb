require 'spec_helper'

describe SlackStrava::Commands::Mixins::ParseDate do
  subject(:parser) { Object.new.extend(described_class) }

  it 'interprets years in date ranges as the start of each year' do
    expect(parser.parse_date_expression('between 2024 and 25')).to eq(
      start_date: Time.new(2024, 1, 1), end_date: Time.new(2025, 1, 1)
    )
  end

  it 'preserves an exact time returned by Chronic in a date range' do
    now = Time.local(2026, 10, 25, 12)
    allow(Chronic).to receive(:parse).with('now', context: :past, guess: false, now: now).and_return(now)
    expect(parser.parse_date_expression('between 2024 and now', now: now)).to eq(
      start_date: Time.new(2024, 1, 1), end_date: now
    )
  end

  it 'rejects an unparseable endpoint instead of silently dropping the date filter' do
    expect { parser.parse_date_expression('between 2024 and not-a-date') }.to raise_error(
      SlackStrava::Error, "Sorry, I don't understand 'not-a-date'."
    )
  end
end
