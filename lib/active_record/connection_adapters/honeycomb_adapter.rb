require 'active_record'
require 'active_support/backtrace_cleaner'
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
        real_connection.class.prepend ConnectionAdapters::HoneycombAdapter
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

        def prepended(klazz)
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

      def execute(sql, name = nil, *args)
        sending_honeycomb_event(sql, name, []) do |event|
          with_tracing_if_available(event) do
            super
          end
        end
      end

      def exec_query(sql, name = 'SQL', binds = [], *args)
        sending_honeycomb_event(sql, name, binds) do |event|
          with_tracing_if_available(event) do
            super
          end
        end
      end

      def exec_insert(sql, name, binds, *args)
        sending_honeycomb_event(sql, name, binds) do |event|
          with_tracing_if_available(event) do
            super
          end
        end
      end

      def exec_delete(sql, name, binds = [], *args)
        sending_honeycomb_event(sql, name, binds) do |event|
          with_tracing_if_available(event) do
            super
          end
        end
      end

      def exec_update(sql, name, binds = [], *args)
        sending_honeycomb_event(sql, name, binds) do |event|
          with_tracing_if_available(event) do
            super
          end
        end
      end

      private
      def sending_honeycomb_event(sql, name, binds)
        # Some adapters have some of their exec* methods call each other,
        # e.g mysql2 has exec_query call execute (via execute_and_free).
        # We don't want to send two events for the same query, so we screen out
        # multiple invocations of this wrapper method in the same call tree.
        if !defined?(@honeycomb_event_depth)
          @honeycomb_event_depth = 0
        end
        if @honeycomb_event_depth < 1
          @honeycomb_event_depth = 1
          event = builder.event

          event.add_field 'db.sql', sql
          event.add_field 'db.query_source', extract_query_source_location(caller)
          event.add_field 'name', name || query_name(sql)

          binds.each do |bind|
            # ActiveRecord 5
            if bind.respond_to?(:value) && bind.respond_to?(:name)
              event.add_field "db.params.#{bind.name}", bind.value
            else # ActiveRecord 4
              column, value = bind
              event.add_field "db.params.#{column.name}", value
            end
          end

          start = Time.now
        else
          @honeycomb_event_depth += 1
        end

        yield event
      rescue Exception => e
        if event
          event.add_field 'db.error', e.class.name
          event.add_field 'db.error_detail', e.message
        end
        raise
      ensure
        @honeycomb_event_depth -= 1
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

      def with_tracing_if_available(event)
        # return if we are not using the ruby beeline
        return yield unless event && defined?(::Honeycomb)

        # beeline version <= 0.5.0
        if ::Honeycomb.respond_to? :trace_id
          trace_id = ::Honeycomb.trace_id
          event.add_field 'trace.trace_id', trace_id if trace_id
          span_id = SecureRandom.uuid
          event.add_field 'trace.span_id', span_id

          ::Honeycomb.with_span_id(span_id) do |parent_span_id|
            event.add_field 'trace.parent_id', parent_span_id
            yield
          end
        # beeline version > 0.5.0
        elsif ::Honeycomb.respond_to? :span_for_existing_event
          ::Honeycomb.span_for_existing_event(
            event,
            name: nil, # leave blank since we set it above
            type: 'db',
          ) do
            yield
          end
        # fallback if we don't detect any known beeline tracing methods
        else
          yield
        end
      end

      def extract_query_source_location(locations)
        backtrace_cleaner.clean(locations).first
      end

      def backtrace_cleaner
        @backtrace_cleaner ||=
          if defined?(Rails)
            Rails.backtrace_cleaner
          else
            ActiveSupport::BacktraceCleaner.new.tap do |cleaner|
              # Ignore ourselves
              cleaner.add_silencer { |l| l.include?(__FILE__) }
              # Ignore activerecord
              cleaner.add_silencer { |l| l.include?("activerecord") }
            end
          end
      end
    end
  end
end
