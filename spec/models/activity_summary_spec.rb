require 'spec_helper'

describe ActivitySummary do
  let(:activity_summary) { Fabricate(:activity_summary) }

  describe '#to_slack' do
    let(:data) { activity_summary.to_slack }

    it 'returns a slack attachment' do
      expect(data).to eq(
        {
          fallback: '14.01mi in 2h6m26s',
          fields: [
            { short: true, title: 'Runs 🏃', value: '8' },
            { short: true, title: 'Athletes', value: '2' },
            { short: true, title: 'Distance', value: '14.01mi' },
            { short: true, title: 'Moving Time', value: '2h6m26s' },
            { short: true, title: 'Elapsed Time', value: '2h8m6s' },
            { short: true, title: 'Elevation', value: '475.4ft' }
          ]
        }
      )
    end
  end
end
