source 'https://rubygems.org'

gemspec

gem 'pry-byebug', group: :development

gem 'activerecord', '< 5'
# required by ActiveRecord 4
gem 'pg', '~> 0.15'
gem 'mysql2', '< 0.5', '>= 0.3.13'
