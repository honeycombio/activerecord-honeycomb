# Alternative gem entrypoint that automagically installs our wrapper into
# ActiveRecord.

begin
  gem 'honeycomb'
  require 'honeycomb/automagic'
  gem 'activerecord'
  require 'active_record'

  require 'activerecord-honeycomb'

  Honeycomb.after_init :activerecord do |client|
    ActiveRecord::Base.extend(Module.new do
      define_method :establish_connection do |config, *args|
        munged_config = ActiveRecord::Honeycomb.munge_config(config, client)
        super(munged_config, *args)
      end
    end)
  end
rescue Gem::LoadError => e
  case e.name
  when 'activerecord'
      puts 'Not autoinitialising activerecord-honeycomb'
  when 'honeycomb'
    warn "Please ensure you `require 'activerecord-honeycomb/automagic'` *after* `require 'honeycomb/automagic'`"
  end
end
