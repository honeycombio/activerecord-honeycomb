require 'support/fakehoney'

RSpec.shared_examples_for 'records a database query' do |name:, sql_match:, sql_not_match: nil|
  it 'sends a db event' do
    expect(last_event.data['type']).to eq('db')
  end

  it "sets 'name' to #{name.inspect} (although something more informative would be nicer!)" do
    expect(last_event.data['name']).to eq(name)
  end

  it 'records the SQL query' do
    expect(last_event.data).to include('db.sql' => sql_match)
  end

  it 'records the parameterised SQL query rather than the literal parameter values' do
    expect(last_event.data['db.sql']).to_not match(sql_not_match)
  end if sql_not_match

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

RSpec.describe 'ActiveRecord::ConnectionAdapters::HoneycombAdapter' do
  let(:last_event) { $fakehoney.events.last }

  context 'after a .create!' do
    before { Animal.create! name: 'Max', species: 'Lion' }

    include_examples 'records a database query',
      name: 'INSERT',
      sql_match: /^INSERT INTO "animals"/,
      sql_not_match: /Lion/
  end

  context 'after a .find' do
    before do
      Animal.create! name: 'Pooh', species: 'Bear'
      @sanders = Animal.find_by(species: 'Bear')
    end

    include_examples 'records a database query',
      name: 'SELECT',
      sql_match: /^SELECT .* FROM "animals"/,
      sql_not_match: /Bear/

    it 'records how many records were returned' do
      pending 'depends on underlying adapter API?'

      expect(last_event.data['db.num_rows_returned']).to eq(1)
    end
  end

  context 'after an update' do
    before do
      @robin = Animal.create! name: 'Robin Hood', species: 'Fox'
      @robin.name = 'Sir Robert of Loxley'
      @robin.save!
    end

    it 'records a database query' do
      pending 'need to hook in at a different level (ActiveRecord::ConnectionAdapters::DatabaseStatements#exec_update)'
      fail "doesn't send events for UPDATE"

      #name: 'UPDATE',
      #sql_match: /^UPDATE "animals"/,
      #sql_not_match: /Loxley/
    end
  end

  context 'after a delete' do
    before do
      @robin = Animal.create! name: 'Robin Hood', species: 'Fox'
      @robin.destroy!
    end

    it 'records a database query' do
      pending 'need to hook in at a different level (ActiveRecord::ConnectionAdapters::DatabaseStatements#exec_delete)'
      fail "doesn't send events for DELETE"

      #name: 'DELETE',
      #sql_match: /^DELETE FROM "animals"/
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
