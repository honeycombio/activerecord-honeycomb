require 'active_record'

module ActiveRecord
  module Honeycomb
    class << self
      def munge_config(config, client: nil, logger: nil)
        config = resolve_config(config)

        return config if config.key?('real_adapter') || config.key?(:real_adapter)

        munged = config.merge(
          'adapter' => 'honeycomb',
          'real_adapter' => config.fetch('adapter'),
        )
        munged['honeycomb_client'] = client if client
        munged['honeycomb_logger'] = logger if logger
        logger.debug "#{self.name}: injected HoneycombAdapter config, original adapter was #{munged['real_adapter'].inspect}" if logger
        munged
      end

      def resolve_config(config)
        # ActiveRecord allows `config` to be a hash, an URL or a Symbol (the
        # latter representing a key into ActiveRecord::Base.configurations,
        # initialized elsewhere) - or even `nil` (in which case it checks the
        # RAILS_ENV global and then falls back to the Symbol path). Rather than
        # handle this mess, we use the same mechanism as
        # ActiveRecord::Base.establish_connection to resolve it into a hash so
        # we can munge it: see
        # https://github.com/rails/rails/blob/9700dac/activerecord/lib/active_record/connection_handling.rb#L56-L57

        resolver = ::ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new(::ActiveRecord::Base.configurations)
        resolver.resolve(config)
      end
    end
  end
end
