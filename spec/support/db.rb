require 'active_record'

require 'activerecord-honeycomb'

require 'support/fakehoney'

module TestDB
  # for the sake of developer convenience, pick a default DB adapter if env not set
  DEFAULT_DB_ADAPTER = 'mysql2'

  DB_DIR = File.expand_path('../db', File.dirname(__FILE__))

  class << self
    attr_reader :connection_pool

    def config(adapter = nil)
      @config ||= begin
        adapter ||= ENV.fetch('DB_ADAPTER', DEFAULT_DB_ADAPTER)
        YAML.load_file("#{DB_DIR}/config-#{adapter}.yml")
      end
    end

    def establish_connection(adapter = nil)
      @connection_pool = ActiveRecord::Base.establish_connection(ActiveRecord::Honeycomb.munge_config(
        config(adapter).fetch('test'),
        client: $fakehoney,
      ))
    end

    def disconnect
      @connection_pool.disconnect
    end
  end
end

class Animal < ActiveRecord::Base
  validates_presence_of :species
end
