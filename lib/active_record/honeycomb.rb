module ActiveRecord
  module Honeycomb
    def self.munge_config(config)
      config.merge(
        'adapter' => 'honeycomb',
        'real_adapter' => config.fetch('adapter'),
      )
    end
  end
end
