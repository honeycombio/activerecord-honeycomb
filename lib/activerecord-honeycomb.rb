begin
  gem 'activerecord'

  require 'active_record/honeycomb'
rescue LoadError
  warn 'ActiveRecord not detected, not enabling activerecord-honeycomb'
end
