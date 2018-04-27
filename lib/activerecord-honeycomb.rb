# Main gem entrypoint (see also lib/activerecord-honeycomb/automagic.rb for an
# alternative entrypoint).

begin
  gem 'activerecord'

  require 'active_record/honeycomb'
rescue LoadError
  warn 'ActiveRecord not detected, not enabling activerecord-honeycomb'
end
