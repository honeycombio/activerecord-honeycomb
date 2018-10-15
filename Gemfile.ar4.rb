source 'https://rubygems.org'

gemspec

gem 'pry-byebug', group: :development

gem 'activerecord', '< 5'
# required by ActiveRecord 4
gem 'pg', '~> 0.15'
