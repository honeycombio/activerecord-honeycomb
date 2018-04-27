module ActiveRecord
  module Honeycomb
    def self.munge_config(config, client = nil)
      munged = config.merge(
        'adapter' => 'honeycomb',
        'real_adapter' => config.fetch('adapter'),
      )
      munged['honeycomb_client'] = client if client
      munged
    end
  end
end
