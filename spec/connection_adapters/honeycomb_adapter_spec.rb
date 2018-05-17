require 'support/fakehoney'

RSpec.describe 'ActiveRecord::ConnectionAdapters::HoneycombAdapter' do
  let(:last_event) { $fakehoney.events.last }

  context 'after a .create!' do
    before { Animal.create! name: 'Max', species: 'Lion' }

    it 'records the SQL query' do
      expect(last_event.data).to include(sql: /^INSERT INTO "animals"/)
    end

    it 'records the parameterised SQL query rather than the literal parameter values' do
      expect(last_event.data[:sql]).to_not match(/Lion/)
    end

    it 'records how long the query took to run' do
      expect(last_event.data[:durationMs]).to be_a Numeric
    end
  end
end
