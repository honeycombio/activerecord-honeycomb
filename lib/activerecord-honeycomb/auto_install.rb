module ActiveRecord
  module Honeycomb
    module AutoInstall
      class << self
        def available?
          gem 'activerecord'
        rescue Gem::LoadError
          false
        end

        def auto_install!(honeycomb_client)
          require 'active_record'
          require 'activerecord-honeycomb'

          ActiveRecord::Base.extend(Module.new do
            define_method :establish_connection do |config, *args|
              munged_config = ActiveRecord::Honeycomb.munge_config(config, honeycomb_client)
              super(munged_config, *args)
            end
          end)
        end
      end
    end
  end
end
