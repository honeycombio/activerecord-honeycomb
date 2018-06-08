module ActiveRecord
  module Honeycomb
    module AutoInstall
      class << self
        def available?(logger: nil)
          gem 'activerecord'
          logger.debug "#{self.name}: detected ActiveRecord, okay to autoinitialise" if logger
          true
        rescue Gem::LoadError => e
          logger.debug "Didn't detect ActiveRecord (#{e.class}: #{e.message}), not autoinitialising activerecord-honeycomb" if logger
          false
        end

        def auto_install!(honeycomb_client:, logger: nil)
          require 'active_record'
          require 'activerecord-honeycomb'

          ActiveRecord::Base.extend(Module.new do
            define_method :establish_connection do |config=nil|
              munged_config = ActiveRecord::Honeycomb.munge_config(config, client: honeycomb_client, logger: logger)
              super(munged_config)
            end
          end)
        end
      end
    end
  end
end
