require 'active_record'
require 'securerandom'

module ActiveRecord
  module ConnectionHandling
    def honeycomb_connection(config)
      log_prefix = "ActiveRecord::ConnectionHandling#honeycomb_connection"

      real_config = config.merge(adapter: config.fetch(:real_adapter))

      logger = config[:honeycomb_logger]
      logger ||= ::Honeycomb.logger if defined?(::Honeycomb.logger)
      ConnectionAdapters::HoneycombAdapter.logger ||= logger

      ConnectionAdapters::HoneycombAdapter.client ||= config[:honeycomb_client]

      logger.debug "#{log_prefix} resolving real database config" if logger
      resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new(Base.configurations)
      spec = resolver.spec(real_config)

      real_connection = ::ActiveRecord::Base.send(spec.adapter_method, spec.config)
      logger.debug "#{log_prefix} obtained real database connection: #{real_connection.class.name}" if logger

      if real_connection.class.ancestors.include? ConnectionAdapters::HoneycombAdapter
        logger.debug "#{log_prefix} found #{real_connection.class} with #{ConnectionAdapters::HoneycombAdapter} already included"
      else
        real_connection.class.include ConnectionAdapters::HoneycombAdapter
      end

      real_connection
    end
  end

  module ConnectionAdapters
    module HoneycombAdapter
      class << self
        attr_accessor :client
        attr_reader :builder
        attr_accessor :logger

        def included(klazz)
          debug "included into #{klazz.name}"

          if @client
            debug "configured with #{@client.class.name}"
          elsif defined?(::Honeycomb.client)
            debug "initialized with #{::Honeycomb.client.class.name} from honeycomb-beeline"
            @client = ::Honeycomb.client
          else
            raise "Please ensure your database config sets :honeycomb_client in order to use #{self.name} (try ActiveRecord::Honeycomb.munge_config)"
          end

          @builder = @client.builder.add(
            'type' => 'db',
            'meta.package' => 'activerecord',
            'meta.package_version' => ActiveRecord::VERSION::STRING,
          )

          super
        end

        private
        def debug(msg)
          @logger.debug("#{self.name}: #{msg}") if @logger
        end
      end

      delegate :builder, to: self

      def execute(sql, *args)
        sending_honeycomb_event do |event|
          event.add_field 'db.sql', sql

          adding_span_metadata_if_available(event, :statement) do
            super
          end
        end
      end

      def exec_query(sql, *args)
        sending_honeycomb_event do |event|
          event.add_field 'db.sql', sql
          event.add_field 'name', query_name(sql)

          adding_span_metadata_if_available(event, :query) do
            super
          end
        end
      end

      private
      def sending_honeycomb_event
        event = builder.event

        start = Time.now
        yield event
      rescue Exception => e
        if event
          event.add_field 'db.error', e.class.name
          event.add_field 'db.error_detail', e.message
        end
        raise
      ensure
        if start && event
          finish = Time.now
          duration = finish - start
          event.add_field 'duration_ms', duration * 1000
          event.send
        end
      end

      def query_name(sql)
        sql.sub(/\s+.*/, '').upcase
      end

      def adding_span_metadata_if_available(event, name)
        return yield unless defined?(::Honeycomb.trace_id)

        trace_id = ::Honeycomb.trace_id

        event.add_field 'trace.trace_id', trace_id if trace_id
        span_id = SecureRandom.uuid
        event.add_field 'trace.span_id', span_id

        ::Honeycomb.with_span_id(span_id) do |parent_span_id|
          event.add_field 'trace.parent_id', parent_span_id
          yield
        end
      end
    end
  end
end
