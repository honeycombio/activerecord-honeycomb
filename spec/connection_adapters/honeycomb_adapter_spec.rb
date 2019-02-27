RSpec.shared_examples_for 'records a database query' do |name:, preceding_events: 0, sql_match:, table:, sql_not_match: nil, binds: {}|
  it 'sends a db event' do
    expect(last_event.data['type']).to eq('db')
  end

  it 'sends just one event' do
    expect($fakehoney.events.size).to eq(preceding_events + 1),
      "expected exactly one event, got: #{$fakehoney.events.drop(preceding_events).map {|event| event.data['name'] }.join(', ')}"
  end

  it "sets 'name' to #{name.inspect}" do
    # certain adapters and versions of active record will populate the name as
    # expected. It should at least containt "SQL" as a fallback
    expect(last_event.data['name']).to eq(name).or eq("SQL")
  end

  it 'records the SQL query' do
    expect(last_event.data).to include('db.sql')
    sql = last_event.data['db.sql']
    expect(sql).to match(sql_match)
    expect(sql).to include(quote_table_name(table))
  end

  it 'records the SQL query source' do
    expect(last_event.data).to include('db.query_source')
    source = last_event.data['db.query_source']
    expect(source).to match(/\w+\.rb:\d+:in `\w+'/)
  end

  # active record 4 and mysql doesn't support parameterised queries
  unless ENV["DB_ADAPTER"] == "mysql2" && ActiveRecord.version < Gem::Version.new("5")
    it 'records the parameterised SQL query rather than the literal parameter values' do
      expect(last_event.data['db.sql']).to_not match(sql_not_match)
    end if sql_not_match
  end

  it 'records the bound parameter values too' do
    param_fields = binds.map do |param, value|
      value = case value
              when Symbol
                instance_variable_get(value)
              else
                value
              end
      ["db.params.#{param}", value]
    end.to_h
    expect(last_event.data).to include(param_fields)
  end unless binds.empty?

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
  let(:last_event) do
    event = $fakehoney.events.last
    expect(event).to_not be_nil
    event
  end

  before :all do
    # For the first query, ActiveRecord fires off some extra "pre-flight"
    # queries to discover the DB schema, and our instrumentation will pick those
    # up. That's not really what we're testing for though, and this will fail
    # our "sent exactly one event" tests if one of those happens to run first.
    #
    # Instead let's force the pre-flight before any tests run.
    _ = Animal.first
  end

  context 'after a .create!' do
    before { Animal.create! name: 'Max', species: 'Lion' }

    include_examples 'records a database query',
      name: 'Animal Create',
      sql_match: /^INSERT INTO /,
      table: :animals,
      sql_not_match: /Lion/,
      binds: {name: 'Max', species: 'Lion'}
  end

  context 'after a .find' do
    before do
      Animal.create! name: 'Pooh', species: 'Bear'
      @sanders = Animal.find_by(species: 'Bear')
    end

    include_examples 'records a database query',
      name: 'Animal Load',
      preceding_events: 1,
      sql_match: /^SELECT .* FROM /,
      table: :animals,
      sql_not_match: /Bear/,
      binds: {species: 'Bear'}

    it 'records how many records were returned' do
      pending 'depends on underlying adapter API?'

      expect(last_event.data['db.num_rows_returned']).to eq(1)
    end
  end

  context 'after an update' do
    before do
      @robin = Animal.create! name: 'Robin Hood', species: 'Fox'
      @robin_id = @robin.id
      @robin.name = 'Sir Robert of Loxley'
      @robin.save!
    end

    include_examples 'records a database query',
      name: 'Animal Update',
      preceding_events: 1,
      sql_match: /^UPDATE /,
      table: :animals,
      sql_not_match: /Loxley/,
      binds: {id: :@robin_id, name: 'Sir Robert of Loxley'}
  end

  context 'after a delete' do
    before do
      @robin = Animal.create! name: 'Robin Hood', species: 'Fox'
      @robin_id = @robin.id
      @robin.destroy!
    end

    include_examples 'records a database query',
      name: 'Animal Destroy',
      preceding_events: 1,
      sql_match: /^DELETE FROM /,
      table: :animals,
      binds: {id: :@robin_id}
  end

  context 'if ActiveRecord raises an error' do
    before do
      expect { Animal.create! }.to raise_error(ActiveRecord::RecordInvalid)

      pending 'need to hook in at a different level'
    end

    it 'records the exception' do
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
