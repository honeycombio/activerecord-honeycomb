require 'support/fakehoney'

RSpec.describe 'ActiveRecord::ConnectionAdapters::HoneycombAdapter' do
  let(:last_event) { $fakehoney.events.last }

  context 'after a .create!' do
    before { Animal.create! name: 'Max', species: 'Lion' }

    it 'sends a db event' do
      expect(last_event.data['type']).to eq('db')
    end

    it 'sets "name" to "INSERT" (although something more informative would be nicer!)' do
      expect(last_event.data['name']).to eq('INSERT')
    end

    it 'records the SQL query' do
      expect(last_event.data).to include('db.sql' => /^INSERT INTO "animals"/)
    end

    it 'records the parameterised SQL query rather than the literal parameter values' do
      expect(last_event.data['db.sql']).to_not match(/Lion/)
    end

    it 'records how long the statement took' do
      expect(last_event.data['duration_ms']).to be_a Numeric
    end

    it 'includes meta fields in the event' do
      expect(last_event.data).to include(
        'meta.package' => 'activerecord',
        'meta.package_version' => ActiveRecord::VERSION::STRING,
      )
    end
  end

  context 'if ActiveRecord raises an error' do
    before do
      expect { Animal.create! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'records the exception' do
      pending 'need to hook in at a different level'

      expect(last_event.data).to include(
        'db.error' => 'ActiveRecord::RecordInvalid',
        'db.error_detail' => /TODO/,
      )
    end

    it 'still records how long the statement took' do
      expect(last_event.data['duration_ms']).to be_a Numeric
    end
  end

  context 'if the database raises an error' do
    before do
      expect { Animal.find_by(habitat: 'jungle') }.to raise_error(ActiveRecord::StatementInvalid, /habitat/)
    end

    it 'records the exception' do
      expect(last_event.data).to include(
        'db.error' => 'ActiveRecord::StatementInvalid',
        'db.error_detail' => /habitat/,
      )
    end

    it 'still records how long the statement took' do
      expect(last_event.data['duration_ms']).to be_a Numeric
    end
  end
end
