lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH << lib unless $LOAD_PATH.include?(lib)
require 'active_record/honeycomb/version'

Gem::Specification.new do |gem|
  gem.name = ActiveRecord::Honeycomb::GEM_NAME
  gem.version = ActiveRecord::Honeycomb::VERSION

  gem.summary = 'Instrument your ActiveRecord queries with Honeycomb'
  gem.description = <<-DESC
    TO DO *is* a description
  DESC

  gem.authors = ['Sam Stokes']
  gem.email = %w(sam@honeycomb.io)
  gem.homepage = 'https://github.com/honeycombio/activerecord-honeycomb'
  gem.license = 'MIT'


  gem.add_development_dependency 'bump'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'yard'

  gem.files = Dir[*%w(
      lib/**/*
      README*)] & %x{git ls-files -z}.split("\0")
end
