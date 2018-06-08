require 'active_record'

module ActiveRecord
  module Honeycomb
    def self.munge_config(config, client: nil, logger: nil)
      munged = config.merge(
        'adapter' => 'honeycomb',
        'real_adapter' => config.fetch('adapter'),
      )
      munged['honeycomb_client'] = client if client
      munged['honeycomb_logger'] = logger if logger
      logger.debug "#{self.name}: injected HoneycombAdapter config, original adapter was #{munged['real_adapter'].inspect}" if logger
      munged
    end
  end
end
