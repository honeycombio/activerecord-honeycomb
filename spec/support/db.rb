require 'active_record'

require 'activerecord-honeycomb'

require 'support/fakehoney'

module TestDB
  DB_DIR = File.expand_path('../db', File.dirname(__FILE__))

  class << self
    attr_reader :connection_pool

    def config
      @config ||= YAML.load_file("#{DB_DIR}/config.yml")
    end

    def establish_connection
      @connection_pool = ActiveRecord::Base.establish_connection(ActiveRecord::Honeycomb.munge_config(
        config.fetch('test'),
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
