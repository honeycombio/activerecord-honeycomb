require 'active_record'
require 'securerandom'

module ActiveRecord
  module ConnectionHandling
    def honeycomb_connection(config)
      real_config = config.merge(adapter: config.fetch(:real_adapter))

      client = config[:honeycomb_client]

      resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new(Base.configurations)
      spec = resolver.spec(real_config)

      real_connection = ::ActiveRecord::Base.send(spec.adapter_method, spec.config)

      unless real_connection.class.ancestors.include? ConnectionAdapters::HoneycombAdapter
        real_connection.class.extend(Module.new do
          private
          define_method(:honeycomb_client) { client }
        end) if client
        real_connection.class.include ConnectionAdapters::HoneycombAdapter
      end

      real_connection
    end
  end

  module ConnectionAdapters
    module HoneycombAdapter
      def self.included(klazz)
        # TODO ugh clean this up
        @_honeycomb ||= begin
          if klazz.respond_to? :honeycomb_client, true # include private
            klazz.send(:honeycomb_client)
          elsif defined?(::Honeycomb.client)
            ::Honeycomb.client
          else
            raise "Can't work without magic global Honeycomb.client at the moment"
          end
        end
        klazz.class_exec(@_honeycomb) do |honeycomb_|
          define_method(:builder) do
            honeycomb_.builder.
              add(
                'type' => 'db',
                'meta.package' => 'activerecord',
                'meta.package_version' => ActiveRecord::VERSION::STRING,
              )
          end
        end
        super
      end

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
        raise 'something went horribly wrong' unless builder # TODO
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
