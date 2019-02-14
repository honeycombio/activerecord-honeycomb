require 'active_record'
require 'bump/tasks'
require 'rspec/core/rake_task'
require 'yaml'
require 'yard'

$LOAD_PATH << "#{File.dirname(__FILE__)}/spec"
require 'support/db'

$db_dir = 'spec/db'

YARD::Rake::YardocTask.new(:doc)

namespace :spec do
  namespace :db do
    include ActiveRecord::Tasks

    task :config do
      # set DB_ADAPTER environment variable to specify which DB adapter to test
      db_config = TestDB.config

      DatabaseTasks.database_configuration = db_config
      DatabaseTasks.env = 'test'
      DatabaseTasks.root = 'spec'
      DatabaseTasks.db_dir = $db_dir
      ActiveRecord::Base.configurations = db_config
    end

    desc 'Create the test database'
    task create: :config do
      DatabaseTasks.create_current
    end

    desc 'Delete the test database'
    task drop: :config do
      DatabaseTasks.drop_current
    end

    desc 'Set up the test database from schema.rb'
    task load_schema: :config do
      if DatabaseTasks.respond_to? :load_schema_current
        DatabaseTasks.load_schema_current(:ruby, nil)
      else
        DatabaseTasks.load_schema(:ruby, nil)
      end
    end
  end
end

RSpec::Core::RakeTask.new(:spec)

task default: :spec
