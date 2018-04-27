require 'securerandom'

module ActiveRecord
  module ConnectionHandling
    def honeycomb_connection(config)
      real_config = config.merge(adapter: config.fetch(:real_adapter))

      if config.key?(:honeycomb_client) && config[:honeycomb_client]
        puts "got honeycomb client"
      end
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
        puts "#{self.name} included into #{klazz.name}"
        @_honeycomb ||= begin
          puts "HONEYCOMBING"
          if klazz.respond_to? :honeycomb_client, true # include private
            klazz.send(:honeycomb_client).tap do |klient|
              puts "got #{klient.nil? ? :nil : :lin} from injection"
            end
          elsif defined?(::Honeycomb.client)
            ::Honeycomb.client.tap do |klient|
              puts "client is #{klient.nil? ? :nil : :lin}"
            end
          else
            raise "Can't work without magic global Honeycomb.client at the moment"
          end
        end
        klazz.class_exec(@_honeycomb) do |honeycomb_|
          define_method(:honeycomb) { honeycomb_ }
        end
        super
      end

      def execute(sql, *args)
        sending_honeycomb_event do |event|
          event.add_field :sql, sql

          adding_span_metadata_if_available(event, :statement) do
            super
          end
        end
      end

      def exec_query(sql, *args)
        sending_honeycomb_event do |event|
          event.add_field :sql, sql

          adding_span_metadata_if_available(event, :query) do
            super
          end
        end
      end

      private
      def sending_honeycomb_event
        raise 'something went horribly wrong' unless honeycomb # TODO
        event = honeycomb.event

        start = Time.now
        yield event
      rescue Exception => e
        if event
          event.add_field :exception_class, e.class
          event.add_field :exception_message, e.message
        end
        raise
      ensure
        if start && event
          finish = Time.now
          duration = finish - start
          event.add_field :durationMs, duration * 1000
          event.send
        end
      end

      def adding_span_metadata_if_available(event, name)
        return yield unless defined?(::Honeycomb.trace_id)

        trace_id = ::Honeycomb.trace_id

        event.add_field :traceId, trace_id if trace_id
        span_id = SecureRandom.uuid
        event.add_field :id, span_id
        event.add_field :serviceName, 'active_record'
        event.add_field :name, name

        ::Honeycomb.with_span_id(span_id) do |parent_span_id|
          event.add_field :parentId, parent_span_id
          yield
        end
      end
    end
  end
end
