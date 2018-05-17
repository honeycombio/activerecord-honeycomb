require 'active_record'
require 'bump/tasks'
require 'rspec/core/rake_task'
require 'yaml'
require 'yard'

$db_dir = 'spec/db'

YARD::Rake::YardocTask.new(:doc)

namespace :spec do
  namespace :db do
    include ActiveRecord::Tasks

    task :config do
      db_config = YAML.load_file("#$db_dir/config.yml")

      DatabaseTasks.database_configuration = db_config
      DatabaseTasks.env = 'test'
      DatabaseTasks.root = 'spec'
      DatabaseTasks.db_dir = $db_dir
      ActiveRecord::Base.configurations = db_config
    end

    desc 'Create the test database file'
    task create: :config do
      DatabaseTasks.create_current
    end

    desc 'Delete the test database file'
    task drop: :config do
      DatabaseTasks.drop_current
    end

    desc 'Set up the test database from schema.rb'
    task load_schema: :config do
      DatabaseTasks.load_schema_current(:ruby, nil)
    end
  end
end

RSpec::Core::RakeTask.new(:spec)

task default: :spec
